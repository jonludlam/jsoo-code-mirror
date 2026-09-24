(* https://codemirror.net/examples/config/ *)

open Brr
open Cm_state
open Cm_view

(*!autoLanguage*)

let language_conf = Compartment.make ()

(* The document is HTML if, after any whitespace, it starts with a tag:
   JavaScript's [/^\s*</]. *)
let starts_with_tag s =
  let s = String.trim s in
  String.length s > 0 && s.[0] = '<'

let is_language state lang =
  match EditorState.facet state Cm_language.language with
  | Some l ->
      Jv.strict_equal
        (Cm_language.Language.to_jv l)
        (Cm_language.LRLanguage.to_jv lang)
  | None -> false

let auto_language =
  Facet.of_ EditorState.transaction_extender (fun tr ->
      if not (Transaction.doc_changed tr) then None
      else
        let doc_is_html =
          starts_with_tag
            (Text.slice_string ~from:0 ~to_:100 (Transaction.new_doc tr))
        in
        let state_is_html =
          is_language (Transaction.start_state tr) Cm_lang_html.html_language
        in
        if doc_is_html = state_is_html then None
        else
          Some
            (TransactionSpec.create
               ~effects:
                 [
                   Compartment.reconfigure language_conf
                     (Cm_language.LanguageSupport.extension
                        (if doc_is_html then Cm_lang_html.html ()
                         else Cm_lang_javascript.javascript ()));
                 ]
               ()))

(*!enable*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"console.log(\"hello\")"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Compartment.of_ language_conf
                  (Cm_language.LanguageSupport.extension
                     (Cm_lang_javascript.javascript ()));
                auto_language;
              ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()
