open Cm_state
open Cm_view
open Example_check

let line n =
  Line.text (Text.line (EditorState.doc (EditorView.state Tab.view)) n)

let () =
  keep [ Tab.view ];
  let view = Tab.view in
  EditorView.dispatch view
    (TransactionSpec.create
       ~selection:(TransactionSpec.Cursor (String.length "if (true) {\n"))
       ());
  check "Tab is the editor's, not the browser's" (fun () ->
      not (press view "Tab"));
  check "Tab indented the line" (fun () -> line 2 = "    console.log(\"okay\")");
  check "Shift-Tab dedents it" (fun () ->
      ignore (press ~shift:true view "Tab");
      line 2 = "  console.log(\"okay\")");
  report ()
