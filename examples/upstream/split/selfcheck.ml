open Cm_state
open Cm_view
open Example_check

let insert v at s =
  EditorView.dispatch v
    (TransactionSpec.create ~changes:(ChangeSpec.insert ~at s)
       ~user_event:"input.type" ())

let () =
  keep [ Split.main (); Option.get !Split.other_view ];
  let main = Split.main () and other = Option.get !Split.other_view in
  check "an edit in the main view reaches the other" (fun () ->
      insert main 0 "Main: ";
      text other = "Main: The document\nis\nshared");
  check "an edit in the other view reaches the main" (fun () ->
      insert other (String.length (text other)) "!";
      text main = "Main: The document\nis\nshared!");
  check "the other view's Mod-z undoes through the main history" (fun () ->
      ignore (press_mod other "z");
      text main = "Main: The document\nis\nshared" && text other = text main);
  check "only the main state keeps a history" (fun () ->
      Cm_commands.undo_depth (EditorView.state main) > 0
      && Cm_commands.undo_depth (EditorView.state other) = 0);
  report ()
