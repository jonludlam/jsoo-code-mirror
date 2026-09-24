open Brr
open Cm_state
open Cm_view
open Example_check

(* The page's two peers are left alone: the check adds two of its own
   with the port's [add_peer], edits in those, and removes them. Its edits
   reach the page's peers only as remote changes, which do not enter their
   undo history, and are taken out again, so the page is left as it
   opened. *)

let peers () =
  El.find_by_class (Jstr.v "cm-editor")
  |> List.filter_map EditorView.find_from_dom

let cut_control view =
  let wrap = Option.get (El.parent (EditorView.dom view)) in
  Option.get
    (El.find_first_by_selector ~root:wrap (Jstr.v ".cut-control input"))

let set_cut view on =
  let input = cut_control view in
  Jv.Bool.set (El.to_jv input) "checked" on;
  ignore (Ev.dispatch (Ev.create Ev.change) (El.as_target input))

let insert view at s =
  EditorView.dispatch view
    (TransactionSpec.create ~changes:(ChangeSpec.insert ~at s)
       ~user_event:"input.type" ())

let () =
  after 1500 @@ fun () ->
  let page_peers = peers () in
  check "the page's two peers load the authority's document" (fun () ->
      List.length page_peers = 2
      && List.for_all (fun v -> text v = "Start document") page_peers);
  Fut.await (Collab.add_peer ()) @@ fun () ->
  Fut.await (Collab.add_peer ()) @@ fun () ->
  match List.filter (fun v -> not (List.memq v page_peers)) (peers ()) with
  | [ a; b ] ->
      insert a 0 "A: ";
      after 1000 @@ fun () ->
      check "an edit in one peer reaches the others through the worker"
        (fun () ->
          text b = "A: Start document"
          && List.for_all (fun v -> text v = "A: Start document") page_peers);
      set_cut b true;
      insert a 0 "cut ";
      after 1000 @@ fun () ->
      check "a cut peer does not see new edits" (fun () ->
          text b = "A: Start document");
      set_cut b false;
      after 1000 @@ fun () ->
      check "reconnected, it catches up" (fun () ->
          text b = "cut A: Start document");
      EditorView.dispatch a
        (TransactionSpec.create
           ~changes:(ChangeSpec.delete ~from:0 ~to_:(String.length "cut A: "))
           ~user_event:"delete" ());
      after 1000 @@ fun () ->
      check "taking the edits out again reaches every peer" (fun () ->
          List.for_all (fun v -> text v = "Start document") (peers ()));
      check "the page's peers have no history of the check's edits" (fun () ->
          List.for_all
            (fun v -> Cm_commands.undo_depth (EditorView.state v) = 0)
            page_peers);
      List.iter
        (fun v ->
          let wrap = El.parent (EditorView.dom v) in
          EditorView.destroy v;
          Option.iter El.remove wrap)
        [ a; b ];
      report ()
  | ps ->
      check
        (Printf.sprintf "add_peer adds two peers (saw %d)" (List.length ps))
        (fun () -> false);
      report ()
