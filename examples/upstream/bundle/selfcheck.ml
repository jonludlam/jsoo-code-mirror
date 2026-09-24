open Cm_state
open Cm_view
open Example_check

let () =
  check "the bundled editor runs, with JavaScript" (fun () ->
      Cm_language.Language.name
        (Option.get
           (EditorState.facet
              (EditorView.state Editor.editor)
              Cm_language.language))
      = "javascript");
  check "the minimal setup draws no gutter" (fun () ->
      by_class Editor.minimal_editor "cm-gutter" = []);
  report ()
