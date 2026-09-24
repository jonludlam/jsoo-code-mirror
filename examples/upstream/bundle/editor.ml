(* https://codemirror.net/examples/bundle/

   Upstream's page is about bundling: a script imports the CodeMirror
   packages it uses, and Rollup resolves them into one file the browser
   loads. Here dune does that job. This directory's [dune] is the Rollup
   configuration: the executable's [libraries] are the imports, each
   library carries its package's JavaScript, and [(modes js)] produces the
   single [editor.bc.js] that [index.html] loads, as upstream's loads
   [editor.bundle.js]. *)

open Brr
open Cm_view

let editor =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~extensions:
           (Cm_state.Extension.of_list
              [
                Code_mirror.basic_setup;
                Cm_language.LanguageSupport.extension
                  (Cm_lang_javascript.javascript ());
              ])
         ~parent:(Document.body G.document) ())
    ()

(* Upstream's smaller variant, with [minimalSetup]. *)
let minimal_editor =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~extensions:Code_mirror.minimal_setup
         ~parent:(Document.body G.document) ())
    ()
