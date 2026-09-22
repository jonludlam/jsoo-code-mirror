(* A TransactionSpec can carry both [changes] and [selection] together:
   the selection's positions refer to the document *after* the changes are
   applied, so a spec can insert text and then select exactly what it
   inserted in one dispatch. *)

open Brr
open Cm_state
open Cm_view

let container = El.div []
let () = El.append_children (Document.body G.document) [ container ]

let config =
  EditorStateConfig.create
    ~doc:"This doesn't have an asterisk in initially\nSome more text\n" ()

let state = EditorState.create ~config ()

let view =
  EditorView.create
    ~config:(EditorViewConfig.create ~state ~parent:container ())
    ()

let () =
  let changes = ChangeSpec.insert ~at:10 "*" in
  let selection = TransactionSpec.Anchor_head { anchor = 10; head = 11 } in
  EditorView.dispatch view (TransactionSpec.create ~changes ~selection ())

(* -- self-check -------------------------------------------------------- *)

open Example_check

let () =
  check "the change inserted the asterisk at position 10" (fun () ->
      let doc = EditorState.doc (EditorView.state view) in
      String.equal (Text.slice_string ~from:10 ~to_:11 doc) "*");

  check "the selection from the same spec selects the inserted text" (fun () ->
      let main =
        EditorSelection.main (EditorState.selection (EditorView.state view))
      in
      SelectionRange.from main = 10 && SelectionRange.to_ main = 11);

  check "the resulting selection is not empty" (fun () ->
      not
        (SelectionRange.empty
           (EditorSelection.main
              (EditorState.selection (EditorView.state view)))));

  report ()
