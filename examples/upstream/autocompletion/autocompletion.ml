(* https://codemirror.net/examples/autocompletion/ *)

open Brr
open Cm_state
open Cm_view
open Cm_autocomplete

let el id = Option.get (Document.find_el_by_id G.document (Jstr.v id))

(*!htmlEditor*)

let html_view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"<!doctype html>\n<html>\n  \n</html>"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Cm_language.LanguageSupport.extension (Cm_lang_html.html ());
              ])
         ~parent:(el "editor-html") ())
    ()

(*!override*)

let my_completions context =
  let word =
    Option.get
      (CompletionContext.match_before context
         (Jv.new' (Jv.get Jv.global "RegExp") [| Jv.of_string {|\w*|} |]))
  in
  if word.from = word.to_ && not (CompletionContext.explicit context) then
    Fut.return None
  else
    Fut.return
      (Some
         (CompletionResult.create ~from:word.from
            ~options:
              [
                Completion.create ~label:"match" ~type_:"keyword" ();
                Completion.create ~label:"hello" ~type_:"variable"
                  ~info:(`Text "(World)") ();
                Completion.create ~label:"magic" ~type_:"text"
                  ~apply:(`Text "⠁⭒*.✩.*⭒⠁") ~detail:"macro" ();
              ]
            ()))

(*!createOverride*)

let override_view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"Press Ctrl-Space in here...\n"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                autocompletion ~override:[ my_completions ] ();
              ])
         ~parent:(el "editor-override") ())
    ()
