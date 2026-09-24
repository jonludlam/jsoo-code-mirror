(* Browser exerciser for the four language packages and the parsing
   machinery they share: each language parses its own syntax, lang-html
   hands <script> and <style> to the other two, a parser configured with
   [parse_mixed] nests one grammar in another, a [TreeCursor] walks a
   tree, and node props added with [fold_node_prop_add] and
   [indent_node_prop_add] reach the language. Reports through
   [window.langTestResults], the same shape test/view uses. *)

open Cm_state
open Cm_language

(* -- bookkeeping ---------------------------------------------------- *)

let details = ref []
let check name f = details := (name, try f () with _ -> false) :: !details

let jv_of_pair (name, ok) =
  Jv.obj [| ("name", Jv.of_string name); ("ok", Jv.of_bool ok) |]

let report () =
  let details = List.rev !details in
  let total = List.length details in
  let passed = List.length (List.filter (fun (_, ok) -> ok) details) in
  Jv.set Jv.global "langTestResults"
    (Jv.obj
       [|
         ("total", Jv.of_int total);
         ("passed", Jv.of_int passed);
         ("failed", Jv.of_int (total - passed));
         ("details", Jv.of_list jv_of_pair details);
         ("done", Jv.true');
       |])

(* -- helpers -------------------------------------------------------- *)

let state_with ext doc =
  EditorState.create
    ~config:(EditorStateConfig.create ~doc ~extensions:ext ())
    ()

(* The node names in [tree], in document order. *)
let names tree =
  let out = ref [] in
  Tree.iterate tree
    ~enter:(fun n ->
      out := SyntaxNode.name n :: !out;
      true)
    ();
  List.rev !out

let has name tree = List.mem name (names tree)
let parse lr doc = Parser.parse (LRParser.to_parser lr) doc
let support s = LanguageSupport.extension s

(* [state]'s tree, parsed to the end of its document. *)
let full_tree state =
  let len = Text.length (EditorState.doc state) in
  Option.get (ensure_syntax_tree state ~upto:len ~timeout:1000 ())

(* The name of the innermost node at [pos] in [state]'s full tree. *)
let inner_at state pos =
  SyntaxNode.name (Tree.resolve_inner (full_tree state) pos ~side:1)

let () =
  check "css parses a rule set" (fun () ->
      has "RuleSet" (parse Cm_lang_css.parser "a { color: red }"));
  check "javascript parses a function" (fun () ->
      has "FunctionDeclaration"
        (parse Cm_lang_javascript.parser "function f() { return 1 }"));
  check "python parses a def" (fun () ->
      has "FunctionDefinition"
        (parse Cm_lang_python.parser "def f():\n  pass\n"));
  check "html parses an element" (fun () ->
      has "Element" (parse Cm_lang_html.parser "<p>hi</p>"));
  check "typescript's dialect knows type annotations" (fun () ->
      let st =
        state_with
          (support (Cm_lang_javascript.javascript ~typescript:true ()))
          "let x: number = 1"
      in
      has "TypeAnnotation" (full_tree st));
  (* lang-html parses a script's content with lang-javascript *)
  check "html() nests JavaScript inside <script>" (fun () ->
      let doc = "<script>let answer = 42</script>" in
      let st = state_with (support (Cm_lang_html.html ())) doc in
      inner_at st (String.length "<script>let ans") = "VariableDefinition");
  check "html() nests CSS inside <style>" (fun () ->
      let doc = "<style>p { color: red }</style>" in
      let st = state_with (support (Cm_lang_html.html ())) doc in
      inner_at st (String.length "<style>p { col") = "PropertyName");
  (* the same, by hand: an HTML parser whose ScriptText is JavaScript *)
  check "parse_mixed nests one parser in another" (fun () ->
      let mixed =
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
      in
      has "VariableDeclaration" (parse mixed "<script>let x = 1</script>"));
  check "a TreeCursor walks the tree in order" (fun () ->
      let seen = ref [] in
      TreeCursor.iterate
        (Tree.cursor (parse Cm_lang_javascript.parser "f(1)"))
        ~enter:(fun n ->
          seen := SyntaxNode.name n :: !seen;
          true)
        ();
      List.rev !seen
      = [
          "Script";
          "ExpressionStatement";
          "CallExpression";
          "VariableName";
          "ArgList";
          "(";
          "Number";
          ")";
        ]);
  check "fold and indent strategies added as props reach the language"
    (fun () ->
      let parser =
        LRParser.configure Cm_lang_javascript.parser
          (ParserConfig.create
             ~props:
               [
                 fold_node_prop_add
                   [ ("ArgList", fun node _ -> fold_inside node) ];
                 indent_node_prop_add [ ("ArgList", fun _ -> `Indent 7) ];
               ]
             ())
      in
      let lang = LRLanguage.define ~parser () in
      let doc = "f(\n1,\n2)" in
      let st =
        state_with (Language.extension (LRLanguage.to_language lang)) doc
      in
      ignore (full_tree st);
      foldable st ~line_start:0 ~line_end:2 = Some (2, String.length doc - 1)
      && get_indentation (`State st) ~pos:5 = Some 7);
  report ()
