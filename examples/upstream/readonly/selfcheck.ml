open Cm_state
open Cm_view
open Example_check

let attr name view = Brr.El.at (Jstr.v name) (EditorView.content_dom view)

let () =
  keep [ Readonly.focusable; Readonly.inert ];
  let f = Readonly.focusable and i = Readonly.inert in
  check "both states are read-only" (fun () ->
      EditorState.read_only (EditorView.state f)
      && EditorState.read_only (EditorView.state i));
  check "neither content element is editable" (fun () ->
      attr "contenteditable" f = Some (Jstr.v "false")
      && attr "contenteditable" i = Some (Jstr.v "false"));
  check "only the first can take focus" (fun () ->
      attr "tabindex" f = Some (Jstr.v "0") && attr "tabindex" i = None);
  check "editing commands refuse a read-only state" (fun () ->
      EditorView.dispatch f
        (TransactionSpec.create ~selection:(TransactionSpec.Cursor 4) ());
      (not (Cm_commands.delete_char_backward f))
      && text f = "I am focusable but not editable");
  report ()
