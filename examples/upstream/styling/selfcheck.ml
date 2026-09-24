open Brr
open Cm_view
open Example_check

let height view = El.bound_h (EditorView.dom view)

let style view sel prop =
  match El.find_first_by_selector ~root:(EditorView.dom view) (Jstr.v sel) with
  | Some el -> Jstr.to_string (El.computed_style (Jstr.v prop) el)
  | None -> ""

let () =
  after 100 @@ fun () ->
  check "my_theme colours the editor" (fun () ->
      Jstr.to_string
        (El.computed_style
           (Jstr.v "background-color")
           (EditorView.dom Styling.themed))
      = "rgb(0, 51, 68)");
  check "my_theme is dark" (fun () ->
      Cm_state.EditorState.facet
        (EditorView.state Styling.themed)
        EditorView.dark_theme);
  check "keywords take my_highlight_style's colour" (fun () ->
      El.find_by_tag_name
        ~root:(EditorView.content_dom Styling.themed)
        (Jstr.v "span")
      |> List.exists (fun el ->
             Jstr.to_string (El.text_content el) = "if"
             && Jstr.to_string (El.computed_style (Jstr.v "color") el)
                = "rgb(255, 204, 102)"));
  check "the fixed-height editor is 300px" (fun () ->
      height Styling.fixed = 300.);
  check "the min-height editor's content is at least 200px" (fun () ->
      style Styling.min_height ".cm-content" "min-height" = "200px");
  report ()
