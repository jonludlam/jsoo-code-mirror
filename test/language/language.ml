(* Browser exerciser for code-mirror.language: defines a tiny hand-written
   StreamParser mode (["let"] is a keyword, digit runs are numbers),
   installs it with syntax_highlighting and a HighlightStyle, and checks
   the DOM. Also exercises syntax_tree/SyntaxNode walking, indent_unit and
   bracket matching. Not a Playwright runner: this page runs itself and
   reports through [window.languageTestResults], the same shape test/view
   uses. *)

open Brr
open Cm_state
open Cm_view
open Cm_language

(* -- bookkeeping ---------------------------------------------------- *)

let details = ref []

let check name f =
  let ok = try f () with _ -> false in
  details := (name, ok) :: !details

let jv_of_pair (name, ok) =
  Jv.obj [| ("name", Jv.of_string name); ("ok", Jv.of_bool ok) |]

let report () =
  let details = List.rev !details in
  let total = List.length details in
  let passed = List.length (List.filter (fun (_, ok) -> ok) details) in
  let failed = total - passed in
  let result =
    Jv.obj
      [|
        ("total", Jv.of_int total);
        ("passed", Jv.of_int passed);
        ("failed", Jv.of_int failed);
        ("details", Jv.of_list jv_of_pair details);
        ("done", Jv.true');
      |]
  in
  Jv.set Jv.global "languageTestResults" result

(* -- a tiny hand-written stream mode: ["let"] is a keyword, a run of
   digits is a number, everything else is plain text ------------------ *)

let is_digit c = String.length c = 1 && c >= "0" && c <= "9"

let token (stream : StringStream.t) () : string option =
  if StringStream.eat_space stream then None
  else if StringStream.match_ stream "let" then Some "keyword"
  else
    match StringStream.peek stream with
    | Some c when is_digit c ->
        ignore (StringStream.eat_while stream is_digit);
        Some "number"
    | _ ->
        ignore (StringStream.next stream);
        None

let stream_parser = StreamParser.create ~token ()
let my_stream_language = StreamLanguage.define stream_parser
let my_language = StreamLanguage.to_language my_stream_language

(* -- highlighting: a fixed class for keywords (checked directly), an
   inline colour for numbers (checked via the injected stylesheet, as
   test/view does for themes) ------------------------------------------ *)

let number_color = "rgb(9, 9, 200)"

let highlight_style =
  HighlightStyle.define
    [
      TagStyle.make ~class_:"cm-test-keyword" [ Tags.keyword ];
      TagStyle.make
        ~style:[ ("color", Cm_view.StyleSpec.Value number_color) ]
        [ Tags.number ];
    ]

(* -- assemble the editor ---------------------------------------------- *)

let doc_text = "let x = (42)\nlet y = 7"
let paren_pos = String.index doc_text '('
let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]

let extensions =
  Extension.of_list
    [
      Language.extension my_language;
      syntax_highlighting highlight_style;
      Facet.of_ indent_unit "  ";
      bracket_matching ();
    ]

let editor_state_config = EditorStateConfig.create ~doc:doc_text ~extensions ()
let editor_state = EditorState.create ~config:editor_state_config ()

let view_config =
  EditorViewConfig.create ~state:editor_state ~parent:container ()

let view = EditorView.create ~config:view_config ()

(* -- checks ------------------------------------------------------------ *)

let content_text () = El.text_content (EditorView.content_dom view)
let contains ~sub s = Jstr.find_sub ~sub:(Jstr.v sub) (Jstr.v s) <> None
let jcontains ~sub s = Jstr.find_sub ~sub:(Jstr.v sub) s <> None

let style_text_contains substr =
  El.find_by_tag_name (Jstr.v "style")
  |> List.exists (fun s -> jcontains ~sub:substr (El.text_content s))

let () =
  check "initial document renders" (fun () ->
      let t = Jstr.to_string (content_text ()) in
      contains ~sub:"let x = (42)" t && contains ~sub:"let y = 7" t);

  check "keyword tokens get the fixed TagStyle class" (fun () ->
      let spans =
        El.find_by_class ~root:(EditorView.dom view) (Jstr.v "cm-test-keyword")
      in
      List.length spans = 2
      && List.for_all
           (fun e -> Jstr.equal (El.text_content e) (Jstr.v "let"))
           spans);

  check "number tokens are styled via the injected stylesheet" (fun () ->
      style_text_contains number_color);

  check "number tokens are their own styled span, not plain text" (fun () ->
      El.find_by_tag_name ~root:(EditorView.dom view) (Jstr.v "span")
      |> List.exists (fun e -> Jstr.equal (El.text_content e) (Jstr.v "42")));

  check "syntax_tree returns a tree we can walk with SyntaxNode" (fun () ->
      let tree = syntax_tree (EditorView.state view) in
      let top = Tree.top_node tree in
      SyntaxNode.from top = 0
      && SyntaxNode.to_ top = String.length doc_text
      &&
      let names = ref [] in
      Tree.iterate tree
        ~enter:(fun n ->
          names := SyntaxNode.name n :: !names;
          true)
        ();
      List.length !names > 2);

  check "indent_unit facet reads back through get_indent_unit" (fun () ->
      get_indent_unit (EditorView.state view) = 2);

  check "match_brackets finds the (42) pair" (fun () ->
      match
        match_brackets (EditorView.state view) ~pos:paren_pos ~dir:`Forward ()
      with
      | Some { matched; start; end_ = Some _; _ } ->
          matched && fst start = paren_pos
      | _ -> false);

  check "bracket_matching extension highlights the pair in the DOM" (fun () ->
      EditorView.dispatch view
        (TransactionSpec.create
           ~selection:(TransactionSpec.Cursor (paren_pos + 1))
           ());
      El.find_first_by_selector ~root:(EditorView.dom view)
        (Jstr.v ".cm-matchingBracket")
      <> None);

  report ()
