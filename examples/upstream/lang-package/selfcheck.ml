open Cm_state
open Cm_view
open Cm_language
open Example_check

let tree view =
  let st = EditorView.state view in
  Option.get
    (ensure_syntax_tree st
       ~upto:(Text.length (EditorState.doc st))
       ~timeout:1000 ())

let names view =
  let out = ref [] in
  Tree.iterate (tree view)
    ~enter:(fun n ->
      out := SyntaxNode.name n :: !out;
      true)
    ();
  List.rev !out

let () =
  let view = Index.view in
  check "the grammar's parser builds the tree" (fun () ->
      let n = names view in
      List.mem "Application" n && List.mem "LineComment" n
      && List.mem "Boolean" n);
  check "comments are highlighted by the style tags" (fun () ->
      let st = EditorView.state view in
      ignore (tree view);
      List.exists
        (fun el ->
          contains ~sub:"absolutely secure"
            (Jstr.to_string (Brr.El.text_content el)))
        (Brr.El.find_by_tag_name
           ~root:(EditorView.content_dom view)
           (Jstr.v "span"))
      && EditorState.facet st language <> None);
  check "an Application folds inside its parentheses" (fun () ->
      let st = EditorView.state view in
      foldable st ~line_start:0
        ~line_end:(Line.to_ (Text.line (EditorState.doc st) 1))
      <> None);
  check "a new line in an Application indents past its start" (fun () ->
      let st = EditorView.state view in
      let pos = Line.to_ (Text.line (EditorState.doc st) 1) in
      get_indentation (`State st) ~pos = Some 2);
  check "the language's line comment token is ;" (fun () ->
      let st = EditorView.state view in
      Jv.to_string
        (Jv.get
           (List.hd
              (EditorState.language_data_at Conv.jv st ~name:"commentTokens"
                 ~pos:1 ()))
           "line")
      = ";");
  report ()
