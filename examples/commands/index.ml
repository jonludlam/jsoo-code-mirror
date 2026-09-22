(* Buttons and key bindings driving the real @codemirror/commands values.
   Every button below calls a command directly - a command is just an
   [editor_view -> bool] - and [default_keymap] is installed as an
   extension so the keyboard drives the same commands. *)

open Brr
open Cm_state
open Cm_view
open Cm_commands

let doc_text = "let make () =\n  let x = 1 in\n  x + 1\n"

(* toggle_comment/toggle_line_comment read a "//" line-comment token off the
   generic language_data facet - the same facet a real @codemirror/language
   Language would populate. We supply it directly here, with no language
   package installed at all. *)
let comment_tokens : Jv.t =
  Jv.callback ~arity:3 (fun (_state : Jv.t) (_pos : Jv.t) (_side : Jv.t) ->
      Jv.of_list Fun.id
        [
          Jv.obj
            [| ("commentTokens", Jv.obj [| ("line", Jv.of_string "//") |]) |];
        ])

let extensions =
  Extension.of_list
    [
      history ();
      (* draws the selection itself, so it shows while a button has focus *)
      draw_selection ();
      Facet.of_ EditorState.language_data comment_tokens;
      Facet.of_ keymap default_keymap;
    ]

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []

let state =
  EditorState.create
    ~config:(EditorStateConfig.create ~doc:doc_text ~extensions ())
    ()

let view =
  EditorView.create
    ~config:(EditorViewConfig.create ~state ~parent:container ())
    ()

(* -- a row of buttons, each calling a command value directly ------------ *)

(* Each hands focus back to the editor, as a key binding would leave it. *)
let button label cmd =
  let b = El.button [ El.txt' label ] in
  ignore
    (Ev.listen Ev.click
       (fun _ ->
         ignore (cmd view);
         EditorView.focus view)
       (El.as_target b));
  b

let buttons =
  El.div
    ~at:At.[ id (Jstr.v "buttons") ]
    [
      button "Undo" undo;
      button "Redo" redo;
      button "Indent more" indent_more;
      button "Indent less" indent_less;
      button "Move line down" move_line_down;
      button "Copy line down" copy_line_down;
      button "Toggle comment" toggle_comment;
      button "Select all" select_all;
    ]

let () = El.append_children (Document.body G.document) [ buttons; container ]

(* -- self-check ---------------------------------------------------- *)

open Example_check


let doc_lines () =
  String.split_on_char '\n'
    (Text.to_string (EditorState.doc (EditorView.state view)))

let set_cursor pos =
  EditorView.dispatch view
    (TransactionSpec.create ~selection:(TransactionSpec.Cursor pos) ())

let key_event key =
  Jv.new'
    (Jv.get Jv.global "KeyboardEvent")
    [| Jv.of_string "keydown"; Jv.obj [| ("key", Jv.of_string key) |] |]
  |> Ev.of_jv

let () =
  keep [ view ];
  check "renders the initial document" (fun () ->
      let t = Jstr.to_string (El.text_content (EditorView.content_dom view)) in
      contains ~sub:"let make ()" t);

  check "the Indent more button's command indents the current line" (fun () ->
      let line2 = String.length "let make () =\n" in
      set_cursor line2;
      ignore (indent_more view);
      (* line 2 starts out "  let x = 1 in"; one more indent unit adds two
         more spaces *)
      List.nth (doc_lines ()) 1 = "    let x = 1 in");

  check "the Undo button's command reverses it (history at work)" (fun () ->
      ignore (undo view);
      List.nth (doc_lines ()) 1 = "  let x = 1 in");

  check "default_keymap runs cursor_char_right on ArrowRight" (fun () ->
      set_cursor 0;
      let handled = run_scope_handlers view (key_event "ArrowRight") "editor" in
      let sel =
        EditorSelection.main (EditorState.selection (EditorView.state view))
      in
      handled && SelectionRange.from sel = 1);

  report ()
