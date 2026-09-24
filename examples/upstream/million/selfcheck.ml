open Cm_state
open Cm_view
open Example_check

let () =
  keep [ Million.view ];
  let doc = EditorState.doc (EditorView.state Million.view) in
  check "two million lines and the closing two" (fun () ->
      Text.lines doc = 2_000_002);
  check "only the viewport is drawn" (fun () ->
      let n = List.length (by_class Million.view "cm-line") in
      n > 0 && n < 1000);
  check "the visible lines are highlighted as HTML" (fun () ->
      List.exists
        (fun el -> Jstr.to_string (Brr.El.text_content el) = "body")
        (Brr.El.find_by_tag_name
           ~root:(EditorView.content_dom Million.view)
           (Jstr.v "span")));
  report ()
