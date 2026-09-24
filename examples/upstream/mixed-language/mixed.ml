(* https://codemirror.net/examples/mixed-language/

   twig.grammar and twig-highlight.js are upstream's. This directory's
   dune runs lezer-generator on the grammar and bundles the parser.js it
   writes, which sets the global the twig section reads. *)

open Brr
open Cm_state
open Cm_view
open Cm_language

let el id = Option.get (Document.find_el_by_id G.document (Jstr.v id))

(*!html*)

let mixed_html_parser =
  LRParser.configure Cm_lang_html.parser
    (ParserConfig.create
       ~wrap:
         (parse_mixed (fun node _input ->
              if SyntaxNode.name node = "ScriptText" then
                Some
                  (NestedParse.create
                     (LRParser.to_parser Cm_lang_javascript.parser))
              else None))
       ())

let mixed_html = LRLanguage.define ~parser:mixed_html_parser ()

(*!showHTML*)

let html_view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           "<!doctype html>\n\
            <script>\n\
           \  function foo() { return true }\n\
            </script>"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Language.extension (LRLanguage.to_language mixed_html);
              ])
         ~parent:(el "html-editor") ())
    ()

(*!twig*)

let twig_parser =
  LRParser.of_jv (Jv.get (Jv.get Jv.global "__twig_grammar") "parser")

(* JavaScript's [/^\s*\{% endif/]. *)
let starts_with_endif s =
  let s = String.trim s in
  String.length s >= 2
  && String.sub s 0 2 = "{%"
  && String.starts_with ~prefix:"endif"
       (String.trim (String.sub s 2 (String.length s - 2)))

let mixed_twig_parser =
  LRParser.configure twig_parser
    (ParserConfig.create
       ~props:
         [
           (* Add basic folding/indent metadata *)
           fold_node_prop_add
             [ ("Conditional", fun node _ -> fold_inside node) ];
           indent_node_prop_add
             [
               ( "Conditional",
                 fun cx ->
                   let closed =
                     starts_with_endif (TreeIndentContext.text_after cx)
                   in
                   let ic = TreeIndentContext.to_indent_context cx in
                   `Indent
                     (IndentContext.line_indent ic
                        (SyntaxNode.from (TreeIndentContext.node cx))
                     + if closed then 0 else IndentContext.unit_ ic) );
             ];
         ]
       ~wrap:
         (parse_mixed (fun node _input ->
              if NodeType.is_top (SyntaxNode.type_ node) then
                Some
                  (NestedParse.create
                     ~overlay:
                       (`Nodes
                          (fun node ->
                            NodeType.name (SyntaxNode.type_ node) = "Text"))
                     (LRParser.to_parser
                        (LRLanguage.parser Cm_lang_html.html_language)))
              else None))
       ())

let twig_language = LRLanguage.define ~parser:mixed_twig_parser ()

(*!showTwig*)

let twig_view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           "<div>\n\
           \  {{ content }}\n\
            {% if extra_content %}\n\
           \  <hr></div><div class=extra>{{ extra_content }}\n\
            {% endif %}\n\
           \  <hr>\n\
            </div>\n"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Language.extension (LRLanguage.to_language twig_language);
              ])
         ~parent:(el "twig-editor") ())
    ()

(*!twigCompletion*)

let twig_autocompletion =
  Facet.of_
    (Language.data (LRLanguage.to_language twig_language))
    (Jv.obj
       [|
         ( "autocomplete",
           Cm_autocomplete.completion_source_conv.to_jv (fun _context ->
               (* Twig completion logic here *) Fut.return None) );
       |])

(*!twigExtension*)

let twig () =
  Extension.of_list
    [
      Language.extension (LRLanguage.to_language twig_language);
      twig_autocompletion;
      LanguageSupport.support (Cm_lang_html.html ());
    ]

(*!showTwig2*)

let twig2_view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           "<h2>hello {{ name }}</h2>\n\
            <script>\n\
           \  let myVar = 100\n\
           \  my\n\
            </script>\n"
         ~extensions:(Extension.of_list [ Code_mirror.basic_setup; twig () ])
         ~parent:(el "twig2-editor") ())
    ()
