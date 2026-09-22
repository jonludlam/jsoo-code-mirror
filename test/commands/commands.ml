(* Browser exerciser for code-mirror.commands: creates real editors and drives
   history, motion, deletion, line, indentation, comment and keymap commands
   against them. Not a Playwright runner: this page just runs itself and
   reports through [window.commandsTestResults], the same shape test/view and
   test/search use. *)

open Brr
open Cm_state
open Cm_view
open Cm_commands

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
  Jv.set Jv.global "commandsTestResults" result

(* -- a small string helper, to locate fixture words without hard-coding
   offsets --------------------------------------------------------- *)

let find_index ~sub s =
  let sub_len = String.length sub and len = String.length s in
  let rec go i =
    if i + sub_len > len then None
    else if String.sub s i sub_len = sub then Some i
    else go (i + 1)
  in
  go 0

(* -- language data: `toggleComment`/`toggleLineComment` read a "//" line
   comment token off the generic `EditorState.language_data` facet, the way
   `@codemirror/commands` itself does (`languageDataAt("commentTokens", ...)`
   walks that facet regardless of whether a real `@codemirror/language`
   Language is installed). No dependency on Cm_language needed for this. -- *)

let comment_tokens_provider : Jv.t =
  Jv.callback ~arity:3 (fun (_state : Jv.t) (_pos : Jv.t) (_side : Jv.t) ->
      Jv.of_list Fun.id
        [
          Jv.obj
            [| ("commentTokens", Jv.obj [| ("line", Jv.of_string "//") |]) |];
        ])

let language_data_ext =
  Facet.of_ EditorState.language_data comment_tokens_provider

(* -- one fresh, isolated editor per check: most checks here mutate the
   document or the selection, so sharing one editor across checks would make
   them order-dependent -------------------------------------------------- *)

let make_editor ?(extensions = []) doc : editor_view =
  let container = El.div [] in
  El.append_children (Document.body G.document) [ container ];
  let extensions = Extension.of_list (history () :: extensions) in
  let editor_state_config = EditorStateConfig.create ~doc ~extensions () in
  let editor_state = EditorState.create ~config:editor_state_config () in
  let view_config =
    EditorViewConfig.create ~state:editor_state ~parent:container ()
  in
  EditorView.create ~config:view_config ()

let doc_string view = Text.to_string (EditorState.doc (EditorView.state view))

let set_cursor view pos =
  EditorView.dispatch view
    (TransactionSpec.create ~selection:(TransactionSpec.Cursor pos) ())

let main_sel view =
  EditorSelection.main (EditorState.selection (EditorView.state view))

let key_event key =
  Jv.new'
    (Jv.get Jv.global "KeyboardEvent")
    [| Jv.of_string "keydown"; Jv.obj [| ("key", Jv.of_string key) |] |]
  |> Brr.Ev.of_jv

(* -- checks ----------------------------------------------------------- *)

let () =
  check "initial document renders" (fun () ->
      let view = make_editor "hello\nworld" in
      let t = Jstr.to_string (El.text_content (EditorView.content_dom view)) in
      find_index ~sub:"hello" t <> None && find_index ~sub:"world" t <> None);

  (* -- History: undo/redo round-trips the document ------------------- *)
  check "undo restores the document after a change" (fun () ->
      let view = make_editor "abcdef" in
      let before = doc_string view in
      set_cursor view 0;
      EditorView.dispatch view
        (TransactionSpec.create ~changes:(ChangeSpec.insert ~at:0 "X") ());
      let after_insert = doc_string view in
      ignore (undo view);
      let after_undo = doc_string view in
      after_insert = "Xabcdef" && after_undo = before);

  check "redo reapplies the change undo removed" (fun () ->
      let view = make_editor "abcdef" in
      set_cursor view 0;
      EditorView.dispatch view
        (TransactionSpec.create ~changes:(ChangeSpec.insert ~at:0 "X") ());
      ignore (undo view);
      let after_undo = doc_string view in
      ignore (redo view);
      let after_redo = doc_string view in
      after_undo = "abcdef" && after_redo = "Xabcdef");

  check "undo_depth/redo_depth reflect the history stack" (fun () ->
      let view = make_editor "abcdef" in
      let before = undo_depth (EditorView.state view) in
      set_cursor view 0;
      EditorView.dispatch view
        (TransactionSpec.create ~changes:(ChangeSpec.insert ~at:0 "X") ());
      let after_change = undo_depth (EditorView.state view) in
      ignore (undo view);
      let after_undo_redo_depth = redo_depth (EditorView.state view) in
      after_change > before && after_undo_redo_depth > 0);

  (* -- Cursor motion --------------------------------------------------- *)
  check "cursor_char_right moves the cursor forward" (fun () ->
      let view = make_editor "abcdef" in
      set_cursor view 0;
      ignore (cursor_char_right view);
      let sel = main_sel view in
      SelectionRange.empty sel && SelectionRange.from sel = 1);

  check "cursor_line_down moves the cursor to the next line" (fun () ->
      let view = make_editor "alpha\nbeta" in
      set_cursor view 0;
      ignore (cursor_line_down view);
      let sel = main_sel view in
      SelectionRange.from sel > 5);

  (* -- Selection --------------------------------------------------------- *)
  check "select_char_right extends the selection" (fun () ->
      let view = make_editor "abcdef" in
      set_cursor view 0;
      ignore (select_char_right view);
      let sel = main_sel view in
      SelectionRange.anchor sel = 0 && SelectionRange.head sel = 1);

  check "select_all selects the entire document" (fun () ->
      let view = make_editor "abcdef" in
      set_cursor view 0;
      ignore (select_all view);
      let sel = main_sel view in
      SelectionRange.from sel = 0 && SelectionRange.to_ sel = 6);

  check "select_line selects the whole current line" (fun () ->
      let view = make_editor "alpha\nbeta gamma\ndelta" in
      let idx = Option.get (find_index ~sub:"gamma" (doc_string view)) in
      set_cursor view idx;
      ignore (select_line view);
      let sel = main_sel view in
      let text =
        EditorState.slice_doc ~from:(SelectionRange.from sel)
          ~to_:(SelectionRange.to_ sel) (EditorView.state view)
      in
      find_index ~sub:"beta gamma" text <> None);

  (* -- Deletion ----------------------------------------------------------- *)
  check "delete_char_forward removes the character after the cursor" (fun () ->
      let view = make_editor "abcdef" in
      set_cursor view 0;
      ignore (delete_char_forward view);
      doc_string view = "bcdef");

  check "delete_line removes the current line" (fun () ->
      let view = make_editor "alpha\nbeta\ngamma" in
      let idx = Option.get (find_index ~sub:"beta" (doc_string view)) in
      set_cursor view idx;
      ignore (delete_line view);
      let d = doc_string view in
      find_index ~sub:"beta" d = None
      && find_index ~sub:"alpha" d <> None
      && find_index ~sub:"gamma" d <> None);

  (* -- Line manipulation --------------------------------------------------- *)
  check "move_line_down moves the current line below the next one" (fun () ->
      let view = make_editor "one\ntwo\nthree" in
      set_cursor view 0;
      ignore (move_line_down view);
      let lines = String.split_on_char '\n' (doc_string view) in
      lines = [ "two"; "one"; "three" ]);

  check "copy_line_down duplicates the current line" (fun () ->
      let view = make_editor "one\ntwo" in
      set_cursor view 0;
      ignore (copy_line_down view);
      let lines = String.split_on_char '\n' (doc_string view) in
      lines = [ "one"; "one"; "two" ]);

  check "insert_newline_and_indent splits the line at the cursor" (fun () ->
      let view = make_editor "abcdef" in
      set_cursor view 3;
      ignore (insert_newline_and_indent view);
      let lines = String.split_on_char '\n' (doc_string view) in
      List.length lines = 2
      && List.nth lines 0 = "abc"
      && find_index ~sub:"def" (List.nth lines 1) <> None);

  (* -- Indentation --------------------------------------------------------- *)
  check "indent_more adds a unit of indentation to the current line" (fun () ->
      let view = make_editor "one\ntwo\nthree" in
      let idx = Option.get (find_index ~sub:"two" (doc_string view)) in
      set_cursor view idx;
      ignore (indent_more view);
      let lines = String.split_on_char '\n' (doc_string view) in
      List.nth lines 1 = "  two");

  check "indent_less removes a unit of indentation from the current line"
    (fun () ->
      let view = make_editor "one\ntwo\nthree" in
      let idx = Option.get (find_index ~sub:"two" (doc_string view)) in
      set_cursor view idx;
      ignore (indent_more view);
      let idx2 = Option.get (find_index ~sub:"two" (doc_string view)) in
      set_cursor view idx2;
      ignore (indent_less view);
      let lines = String.split_on_char '\n' (doc_string view) in
      List.nth lines 1 = "two");

  (* -- Comments: needs the "//" commentTokens language data provider
     assembled above, since this package's toggle_comment/toggle_line_comment
     look it up through Cm_state.EditorState.language_data_at exactly the way
     a real language's data facet would provide it. --------------------- *)
  check "toggle_line_comment adds a line comment" (fun () ->
      let view =
        make_editor ~extensions:[ language_data_ext ] "one\ntwo\nthree"
      in
      let idx = Option.get (find_index ~sub:"two" (doc_string view)) in
      set_cursor view idx;
      ignore (toggle_line_comment view);
      let lines = String.split_on_char '\n' (doc_string view) in
      List.nth lines 1 = "// two");

  check "toggle_line_comment again removes the comment" (fun () ->
      let view =
        make_editor ~extensions:[ language_data_ext ] "one\ntwo\nthree"
      in
      let idx = Option.get (find_index ~sub:"two" (doc_string view)) in
      set_cursor view idx;
      ignore (toggle_line_comment view);
      let idx2 = Option.get (find_index ~sub:"two" (doc_string view)) in
      set_cursor view idx2;
      ignore (toggle_line_comment view);
      let lines = String.split_on_char '\n' (doc_string view) in
      List.nth lines 1 = "two");

  check
    "toggle_comment falls back to line comments when only a line token is \
     provided" (fun () ->
      let view =
        make_editor ~extensions:[ language_data_ext ] "one\ntwo\nthree"
      in
      let idx = Option.get (find_index ~sub:"two" (doc_string view)) in
      set_cursor view idx;
      ignore (toggle_comment view);
      let lines = String.split_on_char '\n' (doc_string view) in
      List.nth lines 1 = "// two");

  (* -- Keymaps: default_keymap and indent_with_tab wired through
     Cm_view.keymap, exercised via Cm_view.run_scope_handlers the way
     test/view/view.ml drives its own keymap check --------------------- *)
  check "default_keymap runs cursor_char_right on ArrowRight" (fun () ->
      let view =
        make_editor ~extensions:[ Facet.of_ keymap default_keymap ] "abcdef"
      in
      set_cursor view 0;
      let handled = run_scope_handlers view (key_event "ArrowRight") "editor" in
      let sel = main_sel view in
      handled && SelectionRange.from sel = 1);

  check "indent_with_tab runs indent_more on Tab" (fun () ->
      let view =
        make_editor
          ~extensions:[ Facet.of_ keymap [ indent_with_tab ] ]
          "one\ntwo\nthree"
      in
      let idx = Option.get (find_index ~sub:"two" (doc_string view)) in
      set_cursor view idx;
      let handled = run_scope_handlers view (key_event "Tab") "editor" in
      let lines = String.split_on_char '\n' (doc_string view) in
      handled && List.nth lines 1 = "  two");

  report ()
