open Cm_state
open Cm_view
open Example_check

let options view =
  Cm_autocomplete.current_completions (EditorView.state view)
  |> List.map Cm_autocomplete.Completion.label

let at_end view =
  let n = String.length (text view) in
  EditorView.dispatch view
    (TransactionSpec.create ~selection:(TransactionSpec.Cursor n) ())

let () =
  keep [ Autocompletion.override_view; Jsdoc.view; Autocompletion.html_view ];
  let o = Autocompletion.override_view in
  at_end o;
  ignore (Cm_autocomplete.start_completion o);
  let js = Jsdoc.view in
  EditorView.dispatch js
    (TransactionSpec.create
       ~selection:
         (TransactionSpec.Cursor
            (String.length "/** Complete tags here\n    @pa"))
       ());
  ignore (Cm_autocomplete.start_completion js);
  let h = Autocompletion.html_view in
  EditorView.dispatch h
    (TransactionSpec.create
       ~selection:
         (TransactionSpec.Cursor (String.length "<!doctype html>\n<html>\n  "))
       ());
  EditorView.dispatch h
    (TransactionSpec.create
       ~changes:
         (ChangeSpec.insert
            ~at:(String.length "<!doctype html>\n<html>\n  ")
            "<")
       ~selection:
         (TransactionSpec.Cursor (String.length "<!doctype html>\n<html>\n  <"))
       ~user_event:"input.type" ());
  ignore (Cm_autocomplete.start_completion h);
  after 300 @@ fun () ->
  check "the override offers only our three completions" (fun () ->
      options o = [ "hello"; "magic"; "match" ]);
  check "inside a JSDoc comment, @pa offers @param first" (fun () ->
      match options js with "@param" :: _ -> true | _ -> false);
  check "the HTML editor completes tag names" (fun () ->
      List.mem "body" (options h));
  report ()
