open Cm_state
open Cm_view
open Example_check

let () =
  check "the basic setup's editor shows its document" (fun () ->
      text Basic.view = "Start document");
  check "the spelled-out setup has the same gutters" (fun () ->
      List.length (by_class Basic.manual_view "cm-gutter")
      = List.length (by_class Basic.view "cm-gutter"));
  check "the spelled-out setup allows several selections" (fun () ->
      EditorState.facet
        (EditorView.state Basic.manual_view)
        EditorState.allow_multiple_selections);
  check "the third editor is TypeScript" (fun () ->
      Cm_language.Language.name
        (Option.get
           (EditorState.facet
              (EditorView.state Basic.typescript_view)
              Cm_language.language))
      = "typescript");
  report ()
