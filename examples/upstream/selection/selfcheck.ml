open Cm_state
open Cm_view
open Example_check

let () =
  let view = Selection.view in
  let sel = EditorState.selection (EditorView.state view) in
  check "the last dispatch inserted the asterisk" (fun () ->
      text view = "Hello, thi*s is a demo document.");
  check "and left one cursor after it" (fun () ->
      match EditorSelection.ranges sel with
      | [ r ] -> SelectionRange.empty r && SelectionRange.head r = 11
      | _ -> false);
  check "a multi-range selection keeps its main index" (fun () ->
      let s =
        EditorSelection.create ~main_index:1
          [
            EditorSelection.range ~anchor:4 ~head:5 ();
            EditorSelection.range ~anchor:6 ~head:7 ();
            EditorSelection.cursor 8;
          ]
      in
      EditorSelection.main_index s = 1
      && List.length (EditorSelection.ranges s) = 3);
  report ()
