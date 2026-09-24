open Cm_state
open Cm_view
open Example_check

let () =
  keep [ Help_panel.view; Word_count.view ];
  let view = Help_panel.view in
  check "F1 opens the help panel above the editor" (fun () ->
      ignore (press view "F1");
      texts (by_class view "cm-help-panel") = [ "F1: Toggle the help panel" ]
      && by_class view "cm-panels-top" <> []);
  check "F1 again closes it" (fun () ->
      ignore (press view "F1");
      by_class view "cm-help-panel" = []);
  let v = Word_count.view in
  let count () = texts (by_class v "cm-panel") in
  check "the word count panel counts the words" (fun () ->
      count () = [ "Word count: 9" ]);
  check "and updates as the document changes" (fun () ->
      EditorView.dispatch v
        (TransactionSpec.create
           ~changes:(ChangeSpec.insert ~at:0 "Two more ")
           ());
      count () = [ "Word count: 11" ]);
  report ()
