(* A linter flagging lines over 40 characters, shown through the lint
   gutter and the diagnostics panel. Each diagnostic carries an [Action]
   the user can apply to fix it. [linter]'s source is asynchronous (it
   returns a [Diagnostic.t list Fut.t]); this one adds a short delay to
   make that honest, and the self-check below waits for it rather than
   asserting immediately, the way test/lint/lint.ml does. *)

open Brr
open Cm_state
open Cm_view
open Cm_lint

let max_len = 40

(* -- the linter: one diagnostic per over-long line, each carrying an
   action that trims the line back down to [max_len] ------------------- *)

let trim_action =
  Action.create ~name:"Trim to 40 chars" (fun view ~from ~to_ ->
      EditorView.dispatch view
        (TransactionSpec.create
           ~changes:(ChangeSpec.delete ~from:(from + max_len) ~to_)
           ()))

let long_line_diagnostics (view : EditorView.t) : Diagnostic.t list Fut.t =
  let text = EditorState.doc (EditorView.state view) in
  let diags = ref [] in
  for n = 1 to Text.lines text do
    let line = Text.line text n in
    if Line.length line > max_len then
      diags :=
        Diagnostic.create ~from:(Line.from line) ~to_:(Line.to_ line)
          ~severity:Severity.Warning
          ~message:
            (Printf.sprintf "line is %d characters, over the %d limit"
               (Line.length line) max_len)
          ~actions:[ trim_action ] ()
        :: !diags
  done;
  (* The delay is what makes this a genuinely asynchronous source, as a
     linter backed by a worker or a language server would be. *)
  Fut.bind (Fut.tick ~ms:150) (fun () -> Fut.return (List.rev !diags))

(* -- assemble the editor ------------------------------------------------ *)

let doc_text =
  "short line\n\
   this line is long enough on its own to exceed the forty character limit\n\
   ok\n\
   and here is another line that is also longer than forty characters"

let expected_long_lines = 2
let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]

let extensions =
  Extension.of_list
    [
      linter long_line_diagnostics;
      lint_gutter ();
      line_numbers ();
      panels ();
      Facet.of_ keymap lint_keymap;
    ]

let editor_state_config = EditorStateConfig.create ~doc:doc_text ~extensions ()
let editor_state = EditorState.create ~config:editor_state_config ()

let view_config =
  EditorViewConfig.create ~state:editor_state ~parent:container ()

let view = EditorView.create ~config:view_config ()

(* -- self-check ----------------------------------------------------------- *)

open Example_check

let has_lint_mark () =
  El.find_first_by_selector ~root:(EditorView.dom view)
    (Jstr.v ".cm-lintRange-warning, .cm-lint-marker-warning")
  <> None

let () =
  keep [ view ];
  check "initial document renders" (fun () ->
      contains ~sub:"short line"
        (Jstr.to_string (El.text_content (EditorView.content_dom view))));

  Fut.await (wait_for ~tries:60 has_lint_mark) (fun found ->
      note "linter (async, delayed) flags every line over 40 characters" found;

      check "diagnostic_count matches the number of long lines" (fun () ->
          diagnostic_count (EditorView.state view) = expected_long_lines);

      (* Open the panel and click the first diagnostic's action button in
         the real DOM the panel renders, rather than calling the action's
         [apply] directly: this exercises the button CodeMirror draws. *)
      ignore (open_lint_panel view);
      let action_button =
        El.find_first_by_selector ~root:(EditorView.dom view)
          (Jstr.v ".cm-diagnosticAction")
      in
      Option.iter El.click action_button;

      Fut.await
        (wait_for ~tries:60 (fun () ->
             diagnostic_count (EditorView.state view) = expected_long_lines - 1))
        (fun trimmed ->
          note
            "clicking the action trims the line, and the linter (async) re-runs"
            trimmed;
          report ()))
