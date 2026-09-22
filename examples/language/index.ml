(* A language from scratch: a hand-written StreamParser for a toy tongue
   (keywords, numbers, strings, line comments), a HighlightStyle mapping its
   tags to colours, and a walk of syntax_tree that reports the node under
   the cursor. No @codemirror/legacy-modes, no pre-built grammar - just the
   token function every StreamLanguage is built from. *)

open Brr
open Cm_state
open Cm_view
open Cm_language

(* -- the toy language's tokenizer --------------------------------------- *)

let keywords = [ "let"; "if"; "then"; "else" ]
let is_digit c = String.length c = 1 && c >= "0" && c <= "9"

let is_word_char c =
  String.length c = 1
  && ((c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c = "_")

(* Stateless: every token is decided within a single call, since nothing in
   this toy language spans a line break. *)
let token (stream : StringStream.t) () : string option =
  if StringStream.eat_space stream then None
  else if StringStream.eat stream (fun c -> c = "#") <> None then (
    StringStream.skip_to_end stream;
    Some "comment")
  else if StringStream.eat stream (fun c -> c = "\"") <> None then (
    let rec consume () =
      match StringStream.next stream with
      | None | Some "\"" -> ()
      | Some _ -> consume ()
    in
    consume ();
    Some "string")
  else
    match StringStream.peek stream with
    | Some c when is_digit c ->
        ignore (StringStream.eat_while stream is_digit);
        Some "number"
    | Some c when is_word_char c ->
        ignore (StringStream.eat_while stream is_word_char);
        if List.mem (StringStream.current stream) keywords then Some "keyword"
        else None (* a plain identifier: consumed, but untagged *)
    | _ ->
        ignore (StringStream.next stream);
        None

let stream_parser =
  StreamParser.create ~token
    ~token_table:
      [
        ("keyword", [ Tags.keyword ]);
        ("number", [ Tags.number ]);
        ("string", [ Tags.string ]);
        ("comment", [ Tags.comment ]);
      ]
    ()

let my_language =
  StreamLanguage.to_language (StreamLanguage.define stream_parser)

(* -- highlighting: a fixed class for keywords (checked directly in the
   DOM), inline colours for the rest (checked via the injected stylesheet,
   as test/language does) --------------------------------------------- *)

let string_color = "#98c379"
let comment_color = "#7d8799"

let highlight_style =
  HighlightStyle.define
    [
      TagStyle.make ~class_:"cm-lang-keyword" [ Tags.keyword ];
      TagStyle.make
        ~style:[ ("color", Cm_view.StyleSpec.Value string_color) ]
        [ Tags.string ];
      TagStyle.make
        ~style:[ ("color", Cm_view.StyleSpec.Value comment_color) ]
        [ Tags.comment ];
    ]

(* -- walking syntax_tree: the node at a position, and its ancestors ----- *)

let node_path_at state pos =
  let tree = syntax_tree state in
  let rec ancestors node acc =
    let acc = SyntaxNode.name node :: acc in
    match SyntaxNode.parent node with
    | Some parent -> ancestors parent acc
    | None -> acc
  in
  String.concat " > " (ancestors (Tree.resolve tree pos) [])

let node_path_div = El.div ~at:At.[ id (Jstr.v "node-path") ] []

let report_node_at state pos =
  El.set_children node_path_div
    [ El.txt' (Printf.sprintf "Node at cursor: %s" (node_path_at state pos)) ]

let cursor_pos state =
  SelectionRange.head (EditorSelection.main (EditorState.selection state))

let track_cursor =
  Facet.of_ EditorView.update_listener (fun vu ->
      if ViewUpdate.selection_set vu || ViewUpdate.doc_changed vu then
        let state = ViewUpdate.state vu in
        report_node_at state (cursor_pos state))

(* -- assemble the editor ------------------------------------------------ *)

let doc_text =
  "# a toy program\nlet x = 42\nlet msg = \"hello\"\nif x then x else x"

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []

let () =
  El.append_children (Document.body G.document) [ container; node_path_div ]

let extensions =
  Extension.of_list
    [
      Language.extension my_language;
      syntax_highlighting highlight_style;
      track_cursor;
    ]

let state =
  EditorState.create
    ~config:(EditorStateConfig.create ~doc:doc_text ~extensions ())
    ()

let view =
  EditorView.create
    ~config:(EditorViewConfig.create ~state ~parent:container ())
    ()

let () = report_node_at (EditorView.state view) 0

(* -- self-check ---------------------------------------------------- *)

let details = ref []
let check name f = details := (name, try f () with _ -> false) :: !details
let contains ~sub s = Jstr.find_sub ~sub:(Jstr.v sub) (Jstr.v s) <> None

let style_text_contains sub =
  El.find_by_tag_name (Jstr.v "style")
  |> List.exists (fun s -> contains ~sub (Jstr.to_string (El.text_content s)))

let () =
  check "keyword tokens get the fixed TagStyle class" (fun () ->
      let spans =
        El.find_by_class ~root:(EditorView.dom view) (Jstr.v "cm-lang-keyword")
      in
      (* "let" x2, "if", "then", "else": 5 keyword occurrences in doc_text *)
      List.length spans = 5);

  check "strings are colored via the injected stylesheet" (fun () ->
      style_text_contains string_color);

  check "syntax_tree can be walked from the root down to the cursor's node"
    (fun () ->
      (* position 1 is inside the leading "#" comment, safely within a
         token rather than on a boundary *)
      let path = node_path_at (EditorView.state view) 1 in
      contains ~sub:"Document > comment" path);

  check "moving the cursor updates the reported node" (fun () ->
      (* the middle of the first "let", safely inside the keyword token *)
      let idx =
        1
        + Option.get
            (String.index_opt (Text.to_string (EditorState.doc state)) 'l')
      in
      EditorView.dispatch view
        (TransactionSpec.create ~selection:(TransactionSpec.Cursor idx) ());
      contains ~sub:"keyword" (Jstr.to_string (El.text_content node_path_div)));

  let details = List.rev !details in
  let total = List.length details in
  let passed = List.length (List.filter (fun (_, ok) -> ok) details) in
  let jv_of_pair (name, ok) =
    Jv.obj [| ("name", Jv.of_string name); ("ok", Jv.of_bool ok) |]
  in
  Jv.set Jv.global "exampleResults"
    (Jv.obj
       [|
         ("total", Jv.of_int total);
         ("passed", Jv.of_int passed);
         ("failed", Jv.of_int (total - passed));
         ("details", Jv.of_list jv_of_pair details);
         ("done", Jv.true');
       |])
