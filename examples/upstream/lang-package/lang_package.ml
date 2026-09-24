(* https://codemirror.net/examples/lang-package/

   The grammar is example.grammar, upstream's own. This directory's dune
   runs lezer-generator on it, as upstream's page describes, and bundles
   the parser.js it writes as parser.bundle.js, which sets the global read
   here: the OCaml side of [import {parser} from "./parser.js"]. *)

open Cm_state
open Cm_language

(*!parser*)

let parser =
  LRParser.of_jv (Jv.get (Jv.get Jv.global "__example_grammar") "parser")

let parser_with_metadata =
  LRParser.configure parser
    (ParserConfig.create
       ~props:
         [
           style_tags
             [
               ("Identifier", [ Tags.variable_name ]);
               ("Boolean", [ Tags.bool ]);
               ("String", [ Tags.string ]);
               ("LineComment", [ Tags.line_comment ]);
               ("( )", [ Tags.paren ]);
             ];
           indent_node_prop_add
             [
               ( "Application",
                 fun context ->
                   let cx = TreeIndentContext.to_indent_context context in
                   `Indent
                     (IndentContext.column cx
                        (SyntaxNode.from (TreeIndentContext.node context))
                     + IndentContext.unit_ cx) );
             ];
           fold_node_prop_add
             [ ("Application", fun node _ -> fold_inside node) ];
         ]
       ())

(*!language*)

let example_language =
  LRLanguage.define ~parser:parser_with_metadata
    ~language_data:
      (Jv.obj [| ("commentTokens", Jv.obj [| ("line", Jv.of_string ";") |]) |])
    ()

(*!completion*)

let example_completion =
  Facet.of_
    (Language.data (LRLanguage.to_language example_language))
    (Jv.obj
       [|
         ( "autocomplete",
           Cm_autocomplete.completion_source_conv.to_jv
             (Cm_autocomplete.complete_from_list
                Cm_autocomplete.Completion.
                  [
                    create ~label:"defun" ~type_:"keyword" ();
                    create ~label:"defvar" ~type_:"keyword" ();
                    create ~label:"let" ~type_:"keyword" ();
                    create ~label:"cons" ~type_:"function" ();
                    create ~label:"car" ~type_:"function" ();
                    create ~label:"cdr" ~type_:"function" ();
                  ]) );
       |])

(*!support*)

let example () =
  LanguageSupport.create
    (LRLanguage.to_language example_language)
    ~support:example_completion ()
