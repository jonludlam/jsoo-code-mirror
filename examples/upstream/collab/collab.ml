(* https://codemirror.net/examples/collab/ *)

open Brr
open Cm_state
open Cm_view
open Cm_collab

let ( let* ) = Fut.bind
let pause time = Fut.tick ~ms:(int_of_float time)

let current_latency () =
  let latency =
    Option.get (Document.find_el_by_id G.document (Jstr.v "latency"))
  in
  let base =
    Jv.to_float
      (Jv.call Jv.global "Number" [| Jv.get (El.to_jv latency) "value" |])
  in
  base *. (1. +. (Random.float 1. -. 0.5))

type disconnected = { wait : unit Fut.t; resolve : unit -> unit }

type connection = {
  worker : Jv.t;
  get_latency : unit -> float;
  mutable disconnected : disconnected option;
}

let connection ?(get_latency = current_latency) worker =
  { worker; get_latency; disconnected = None }

let request_ connection value : Jv.t Fut.t =
  let result, resolve = Fut.create () in
  let channel = Jv.new' (Jv.get Jv.global "MessageChannel") [||] in
  Jv.set (Jv.get channel "port2") "onmessage"
    (Jv.callback ~arity:1 (fun event ->
         resolve
           (Result.get_ok (Json.decode (Jv.to_jstr (Jv.get event "data"))))));
  ignore
    (Jv.call connection.worker "postMessage"
       [|
         Jv.of_jstr (Json.encode value);
         Jv.of_list Fun.id [ Jv.get channel "port1" ];
       |]);
  result

let request connection value =
  let latency = connection.get_latency () in
  let wait () =
    match connection.disconnected with
    | Some d -> d.wait
    | None -> Fut.return ()
  in
  let* () = wait () in
  let* () = pause latency in
  let* result = request_ connection value in
  let* () = wait () in
  let* () = pause latency in
  Fut.return result

let set_connected connection value =
  match connection.disconnected with
  | Some d when value ->
      d.resolve ();
      connection.disconnected <- None
  | None when not value ->
      let wait, resolve = Fut.create () in
      connection.disconnected <- Some { wait; resolve }
  | _ -> ()

(*!wrappers*)

let push_updates connection version full_updates : bool Fut.t =
  (* Strip off transaction data *)
  let updates =
    List.map
      (fun u ->
        Jv.obj
          [|
            ("clientID", Jv.of_string (Update.client_id u));
            ("changes", ChangeSet.to_json (Update.changes u));
          |])
      full_updates
  in
  let* r =
    request connection
      (Jv.obj
         [|
           ("type", Jv.of_string "pushUpdates");
           ("version", Jv.of_int version);
           ("updates", Jv.of_list Fun.id updates);
         |])
  in
  Fut.return (Jv.to_bool r)

let pull_updates connection version : Update.t list Fut.t =
  let* updates =
    request connection
      (Jv.obj
         [|
           ("type", Jv.of_string "pullUpdates"); ("version", Jv.of_int version);
         |])
  in
  Fut.return
    (Jv.to_list
       (fun u ->
         Update.create
           ~changes:(ChangeSet.of_json (Jv.get u "changes"))
           ~client_id:(Jv.to_string (Jv.get u "clientID"))
           ())
       updates)

let get_document connection : (int * Text.t) Fut.t =
  let* data =
    request connection (Jv.obj [| ("type", Jv.of_string "getDocument") |])
  in
  Fut.return
    ( Jv.Int.get data "version",
      Text.of_lines
        (String.split_on_char '\n' (Jv.to_string (Jv.get data "doc"))) )

(*!peerExtension*)

type peer = {
  view : EditorView.t;
  mutable pushing : bool;
  mutable done_ : bool;
}

let peer_extension start_version connection =
  let rec push this =
    let updates = sendable_updates (EditorView.state this.view) in
    if this.pushing || updates = [] then Fut.return ()
    else (
      this.pushing <- true;
      let version = get_synced_version (EditorView.state this.view) in
      let* _ = push_updates connection version updates in
      this.pushing <- false;
      (* Regardless of whether the push failed or new updates came in
         while it was running, try again if there's updates remaining *)
      if sendable_updates (EditorView.state this.view) <> [] then
        ignore (G.set_timeout ~ms:100 (fun () -> ignore (push this)));
      Fut.return ())
  in
  let rec pull this =
    if this.done_ then Fut.return ()
    else
      let version = get_synced_version (EditorView.state this.view) in
      let* updates = pull_updates connection version in
      EditorView.dispatch_transaction this.view
        (receive_updates (EditorView.state this.view) updates);
      pull this
  in
  let plugin =
    ViewPlugin.define
      ~update:(fun this update ->
        if ViewUpdate.doc_changed update then ignore (push this))
      ~destroy:(fun this -> this.done_ <- true)
      (fun view ->
        let this = { view; pushing = false; done_ = false } in
        ignore (pull this);
        this)
  in
  Extension.of_list [ collab ~start_version (); ViewPlugin.extension plugin ]

(*!rest*)

let worker =
  Jv.new' (Jv.get Jv.global "Worker") [| Jv.of_string "./worker/worker.bc.js" |]

let add_peer () =
  let* version, doc =
    get_document (connection worker ~get_latency:(fun () -> 0.))
  in
  let connection = connection worker in
  let state =
    EditorState.create
      ~config:
        (EditorStateConfig.create ~text:doc
           ~extensions:
             (Extension.of_list
                [ Code_mirror.basic_setup; peer_extension version connection ])
           ())
      ()
  in
  let editors =
    Option.get (Document.find_el_by_id G.document (Jstr.v "editors"))
  in
  let wrap = El.div ~at:At.[ class' (Jstr.v "editor") ] [] in
  El.append_children editors [ wrap ];
  let cut = El.div ~at:At.[ class' (Jstr.v "cut-control") ] [] in
  El.append_children wrap [ cut ];
  Jv.set (El.to_jv cut) "innerHTML"
    (Jv.of_string "<label><input type=checkbox aria-description='Cut'>✂️</label>");
  let input =
    Option.get (El.find_first_by_selector ~root:cut (Jstr.v "input"))
  in
  ignore
    (Ev.listen Ev.change
       (fun e ->
         let is_cut = Jv.Bool.get (Jv.get (Ev.to_jv e) "target") "checked" in
         El.set_class (Jstr.v "cut") is_cut wrap;
         set_connected connection (not is_cut))
       (El.as_target input));
  ignore
    (EditorView.create
       ~config:(EditorViewConfig.create ~state ~parent:wrap ())
       ());
  Fut.return ()

let () =
  let addpeer =
    Option.get (Document.find_el_by_id G.document (Jstr.v "addpeer"))
  in
  Jv.set (El.to_jv addpeer) "onclick"
    (Jv.callback ~arity:1 (fun _ -> ignore (add_peer ())));
  ignore (add_peer ());
  ignore (add_peer ())
