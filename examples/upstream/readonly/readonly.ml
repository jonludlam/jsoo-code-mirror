(* https://codemirror.net/examples/readonly/ *)

open Brr
open Cm_state
open Cm_view

let el id = Option.get (Document.find_el_by_id G.document (Jstr.v id))

(*!tabindex*)

let focusable =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~parent:(el "editor_focus")
         ~doc:"I am focusable but not editable"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Facet.of_ EditorState.read_only_facet true;
                Facet.of_ EditorView.editable false;
                Facet.of_ EditorView.content_attributes [ ("tabindex", "0") ];
              ])
         ())
    ()

(*!inert*)

let inert =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~parent:(el "editor_inert")
         ~doc:"I am read-only and non-focusable"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Facet.of_ EditorState.read_only_facet true;
                Facet.of_ EditorView.editable false;
              ])
         ())
    ()
