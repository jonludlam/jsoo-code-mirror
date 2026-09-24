open Cm_state
open Cm_view
open Cm_language
open Example_check

let full view =
  let st = EditorView.state view in
  ensure_syntax_tree st
    ~upto:(Text.length (EditorState.doc st))
    ~timeout:1000 ()

let at view pos =
  let st = EditorView.state view in
  ignore (full view);
  SyntaxNode.name (Tree.resolve_inner (syntax_tree st) pos ~side:1)

let () =
  check "the script's content is parsed as JavaScript" (fun () ->
      at Mixed.html_view
        (String.length "<!doctype html>\n<script>\n  function f")
      = "VariableDefinition");
  check "twig's directives are its own nodes" (fun () ->
      at Mixed.twig_view (String.length "<div>\n  {{ con") = "DirectiveContent");
  check "and the text between them is HTML" (fun () ->
      at Mixed.twig_view (String.length "<d") = "TagName");
  check "a Conditional folds" (fun () ->
      let st = EditorView.state Mixed.twig_view in
      let l = Text.line (EditorState.doc st) 3 in
      foldable st ~line_start:(Line.from l) ~line_end:(Line.to_ l) <> None);
  check "the twig() extension brings HTML's support: script is JavaScript"
    (fun () ->
      at Mixed.twig2_view
        (String.length "<h2>hello {{ name }}</h2>\n<script>\n  let my")
      = "VariableDefinition");
  report ()
