(* https://codemirror.net/examples/bidi/ *)

open Brr
open Cm_state
open Cm_view

let el id = Option.get (Document.find_el_by_id G.document (Jstr.v id))

(*!create*)

let rtl_view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           "זהו עורך קוד מימין לשמאל.\n\
            يحتوي على شريط التمرير على الجانب الأيمن\n"
         ~extensions:Code_mirror.basic_setup ~parent:(el "rtl_editor") ())
    ()

let isolate_view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"النص <span class=\"blue\">الأزرق</span>\n"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Cm_language.LanguageSupport.extension (Cm_lang_html.html ());
                Cm_language.bidi_isolates ();
              ])
         ~parent:(el "isolate_editor") ())
    ()
