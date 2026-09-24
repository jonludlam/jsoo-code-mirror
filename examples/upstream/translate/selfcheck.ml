open Cm_state
open Cm_view
open Example_check

let () =
  keep [ Translate.view ];
  let view = Translate.view in
  check "phrase looks strings up in the table" (fun () ->
      EditorState.phrase (EditorView.state view) "Find" = "Suchen");
  check "the control character's title is German" (fun () ->
      List.exists
        (fun el ->
          match Brr.El.at (Jstr.v "title") el with
          | Some t -> contains ~sub:"Steuerzeichen" (Jstr.to_string t)
          | None -> false)
        (by_class view "cm-specialChar"));
  check "Ctrl-F opens the search panel in German" (fun () ->
      ignore (Cm_search.open_search_panel view);
      let t = Jstr.to_string (Brr.El.text_content (EditorView.dom view)) in
      contains ~sub:"nächste" t && contains ~sub:"alle ersetzen" t);
  report ()
