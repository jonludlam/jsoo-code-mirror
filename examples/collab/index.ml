(* Two independently editable CodeMirror views sharing one document
   through [collab], modelled on
   https://codemirror.net/examples/collab/. That example runs the
   authority (the accepted history of updates) in a web worker, reaching
   it from each editor with an async request; here, since editors and
   authority are all OCaml values in one page, [Authority] below is just a
   ref cell, and a timer plays the network's part instead of a worker. A
   real deployment differs in two ways: the authority lives on a server
   neither editor's process can see directly, so "push" and "pull" are
   genuine network requests rather than direct calls; and the pull is a
   long poll (the client sends the version it already has, and the server
   holds the request open until there is something newer to answer with,
   or a timeout) rather than this timer's fixed-interval re-ask regardless
   of whether anything changed. *)

open Brr
open Cm_state
open Cm_view
open Cm_collab

(* -- the authority --------------------------------------------------------- *)

(* Holds every update ever accepted, oldest first; the version is its
   length. This is exactly the shape CodeMirror's own example authority
   uses. *)
module Authority : sig
  val push : version:int -> Update.t list -> unit
  val pull : version:int -> Update.t list
  val version : unit -> int
end = struct
  let history : Update.t list ref = ref []

  let rec drop n l =
    if n <= 0 then l else match l with [] -> [] | _ :: tl -> drop (n - 1) tl

  let version () = List.length !history

  let push ~version updates =
    match updates with
    | [] -> ()
    | updates ->
        let missed = drop version !history in
        let accepted =
          if missed = [] then updates else rebase_updates updates ~over:missed
        in
        history := !history @ accepted

  let pull ~version = drop version !history
end

(* -- one collaborating editor ---------------------------------------------- *)

let make_peer ~client_id ~doc =
  let extensions =
    Extension.of_list [ collab ~client_id (); line_numbers () ]
  in
  let config = EditorStateConfig.create ~doc ~extensions () in
  let state = EditorState.create ~config () in
  let container = El.div ~at:At.[ id (Jstr.v ("editor-" ^ client_id)) ] [] in
  let view_config = EditorViewConfig.create ~state ~parent:container () in
  ( El.div [ El.h2 [ El.txt' ("editor " ^ client_id) ]; container ],
    EditorView.create ~config:view_config () )

let initial_doc = "Type here, or in the other editor.\n"
let column_a, view_a = make_peer ~client_id:"A" ~doc:initial_doc
let column_b, view_b = make_peer ~client_id:"B" ~doc:initial_doc

let row =
  El.div
    ~at:At.[ style (Jstr.v "display: flex; gap: 1em") ]
    [ column_a; column_b ]

let () = El.append_children (Document.body G.document) [ row ]

(* -- syncing ---------------------------------------------------------------- *)

(* One round for one editor: send whatever it has that the authority
   hasn't seen, then fetch whatever the authority has that it hasn't seen
   (which, after a successful push, includes its own updates coming back
   -- that round trip is how the editor learns they were accepted and
   advances its synced version; see collab.receiveUpdates). *)
let sync_peer view =
  let state = EditorView.state view in
  let version = get_synced_version state in
  Authority.push ~version (sendable_updates state);
  match Authority.pull ~version with
  | [] -> ()
  | missing ->
      EditorView.dispatch_transaction view (receive_updates state missing)

let rec loop () : unit Fut.t =
  sync_peer view_a;
  sync_peer view_b;
  Fut.bind (Fut.tick ~ms:30) loop

let () = ignore (loop ())

(* -- self-check --------------------------------------------------------------- *)

open Example_check

let doc_of view = Text.to_string (EditorState.doc (EditorView.state view))

let () =
  check "both editors start with the same document" (fun () ->
      doc_of view_a = doc_of view_b);

  (* Insert into A, as typing at the end of the document would. *)
  let from_a = "hello from A" in
  let version_before = get_synced_version (EditorView.state view_a) in
  EditorView.dispatch view_a
    (TransactionSpec.create
       ~changes:(ChangeSpec.insert ~at:(String.length initial_doc) from_a)
       ());

  Fut.await
    (wait_for ~ms:20 ~tries:150 (fun () -> contains ~sub:from_a (doc_of view_b)))
    (fun reached_b ->
      note "a change typed into editor A reaches editor B" reached_b;

      check "editor B's synced version advanced" (fun () ->
          get_synced_version (EditorView.state view_b) > version_before);

      (* Now type into B too, and check both converge on one document. *)
      let from_b = "hello from B" in
      let doc_b = doc_of view_b in
      EditorView.dispatch view_b
        (TransactionSpec.create
           ~changes:(ChangeSpec.insert ~at:(String.length doc_b) from_b)
           ());

      Fut.await
        (wait_for ~ms:20 ~tries:150 (fun () ->
             contains ~sub:from_b (doc_of view_a)
             && doc_of view_a = doc_of view_b))
        (fun converged ->
          note
            "a change typed into editor B reaches editor A, and the two \
             documents converge"
            converged;

          check "both editors are synced to the authority's version" (fun () ->
              let va = get_synced_version (EditorView.state view_a) in
              let vb = get_synced_version (EditorView.state view_b) in
              va = vb && va = Authority.version ());

          (* Their states belong to the authority's history, so rather than
             being put back the check's text is taken out again, which
             reaches both; neither keeps a history of it. *)
          EditorView.dispatch view_a
            (TransactionSpec.create
               ~changes:
                 (ChangeSpec.delete
                    ~from:(String.length initial_doc)
                    ~to_:(String.length (doc_of view_a)))
               ());
          Fut.await
            (wait_for ~ms:20 ~tries:150 (fun () ->
                 doc_of view_a = initial_doc && doc_of view_b = initial_doc))
            (fun restored ->
              note "taking the check's text out again reaches both" restored;
              report ())))
