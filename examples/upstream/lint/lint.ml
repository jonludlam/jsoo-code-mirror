(* https://codemirror.net/examples/lint/ *)

open Brr
open Cm_state
open Cm_view

(*!regexpLint*)

let regexp_linter =
  Cm_lint.linter (fun view ->
      let diagnostics = ref [] in
      Cm_language.TreeCursor.iterate
        (Cm_language.Tree.cursor
           (Cm_language.syntax_tree (EditorView.state view)))
        ~enter:(fun node ->
          if Cm_language.SyntaxNode.name node = "RegExp" then
            diagnostics :=
              Cm_lint.Diagnostic.create
                ~from:(Cm_language.SyntaxNode.from node)
                ~to_:(Cm_language.SyntaxNode.to_ node)
                ~severity:Warning ~message:"Regular expressions are FORBIDDEN"
                ~actions:
                  [
                    Cm_lint.Action.create ~name:"Remove" (fun view ~from ~to_ ->
                        EditorView.dispatch view
                          (TransactionSpec.create
                             ~changes:(ChangeSpec.delete ~from ~to_)
                             ()));
                  ]
                ()
              :: !diagnostics;
          true)
        ();
      Fut.return (List.rev !diagnostics))

(*!editor*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           {|function isNumber(string) {
  return /^\d+(\.\d*)?$/.test(string)
}|}
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Cm_language.LanguageSupport.extension
                  (Cm_lang_javascript.javascript ());
                Cm_lint.lint_gutter ();
                regexp_linter;
              ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()
