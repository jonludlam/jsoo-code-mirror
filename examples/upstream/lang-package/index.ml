(* https://codemirror.net/examples/lang-package/, upstream's index.js *)

open Brr
open Cm_view

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           "(defun check-login (name password) ; absolutely secure\n\
           \  (if (equal name \"admin\")\n\
           \    (equal password \"12345\")\n\
           \    #t))"
         ~extensions:
           (Cm_state.Extension.of_list
              [
                Code_mirror.basic_setup;
                Cm_language.LanguageSupport.extension (Lang_package.example ());
              ])
         ~parent:
           (Option.get (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()
