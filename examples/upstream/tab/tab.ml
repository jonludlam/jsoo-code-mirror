(* https://codemirror.net/examples/tab/ *)

open Brr
open Cm_state
open Cm_view

(*!editor*)

let doc =
  {|if (true) {
  console.log("okay")
} else {
  console.log("oh no")
}
|}

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Facet.of_ keymap [ Cm_commands.indent_with_tab ];
                Cm_language.LanguageSupport.extension
                  (Cm_lang_javascript.javascript ());
              ])
         ~parent:
           (Option.get (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()
