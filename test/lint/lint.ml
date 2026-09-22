(* Browser exerciser for code-mirror.lint: creates a real editor whose
   [linter] flags any line containing the word "bad", waits for the
   (delayed, asynchronous) linter to run, and checks that the lint mark
   appears in the DOM, [set_diagnostics] applied through a dispatched spec
   works, [diagnostic_count]/[for_each_diagnostic] see the same diagnostics,
   the lint panel opens and closes, [lint_keymap] is wired through
   [keymap], and [next_diagnostic] runs. Not a Playwright runner: this page
   just runs itself and reports through [window.lintTestResults], the same
   shape test/view and test/link use. *)

open Brr
open Cm_state
open Cm_view
open Cm_lint

(* -- bookkeeping ---------------------------------------------------- *)

let details = ref []
let check name f = details := (name, try f () with _ -> false) :: !details
let note name ok = details := (name, ok) :: !details

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
  Jv.set Jv.global "lintTestResults" result

let contains ~sub s = Jstr.find_sub ~sub:(Jstr.v sub) (Jstr.v s) <> None

(* -- a linter flagging any line containing "bad" --------------------- *)

let bad_diagnostics (view : EditorView.t) : Diagnostic.t list Fut.t =
  let text = EditorState.doc (EditorView.state view) in
  let diags = ref [] in
  for n = 1 to Text.lines text do
    let line = Text.line text n in
    if contains ~sub:"bad" (Line.text line) then
      diags :=
        Diagnostic.create ~from:(Line.from line) ~to_:(Line.to_ line)
          ~severity:Severity.Error ~message:"found \"bad\"" ()
        :: !diags
  done;
  Fut.return (List.rev !diags)

(* -- assemble the editor --------------------------------------------- *)

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]
let lint_keymap_ext = Facet.of_ keymap lint_keymap

let extensions =
  Extension.of_list
    [
      linter ~delay:20 bad_diagnostics;
      lint_gutter ();
      panels ();
      lint_keymap_ext;
    ]

let editor_state_config =
  EditorStateConfig.create ~doc:"hello\nthis line is bad\nworld" ~extensions ()

let editor_state = EditorState.create ~config:editor_state_config ()

let view_config =
  EditorViewConfig.create ~state:editor_state ~parent:container ()

let view = EditorView.create ~config:view_config ()

(* -- wait for the delayed, asynchronous linter to run ---------------- *)

let has_lint_mark () =
  El.find_first_by_selector ~root:(EditorView.dom view)
    (Jstr.v ".cm-lintRange-error")
  <> None
  || El.find_first_by_selector ~root:(EditorView.dom view)
       (Jstr.v ".cm-lintPoint-error")
     <> None
  || El.find_first_by_selector ~root:(EditorView.dom view)
       (Jstr.v ".cm-lint-marker-error")
     <> None

let rec wait_for ~tries (pred : unit -> bool) : bool Fut.t =
  if pred () then Fut.return true
  else if tries <= 0 then Fut.return false
  else Fut.bind (Fut.tick ~ms:50) (fun () -> wait_for ~tries:(tries - 1) pred)

(* -- run the checks; the async ones are chained after the initial wait  *)

let () =
  check "initial document renders" (fun () ->
      let t = Jstr.to_string (El.text_content (EditorView.content_dom view)) in
      contains ~sub:"hello" t && contains ~sub:"bad" t);

  Fut.await (wait_for ~tries:60 has_lint_mark) (fun found ->
      note "linter (async, delayed) marks the line containing \"bad\"" found;

      check "diagnostic_count sees the linter's diagnostic" (fun () ->
          diagnostic_count (EditorView.state view) = 1);

      check "for_each_diagnostic iterates the same diagnostics" (fun () ->
          let n = ref 0 in
          for_each_diagnostic (EditorView.state view) (fun d ~from:_ ~to_:_ ->
              if Diagnostic.severity d = Severity.Error then incr n);
          !n = diagnostic_count (EditorView.state view));

      check "set_diagnostics, dispatched, replaces the diagnostic set"
        (fun () ->
          let st = EditorView.state view in
          let manual =
            [
              Diagnostic.create ~from:0 ~to_:5 ~severity:Severity.Warning
                ~message:"manual one" ();
              Diagnostic.create ~from:6 ~to_:9 ~severity:Severity.Info
                ~message:"manual two" ();
            ]
          in
          EditorView.dispatch view (set_diagnostics st manual);
          diagnostic_count (EditorView.state view) = 2);

      check "set_diagnostics_effect is present on the dispatched transaction"
        (fun () ->
          let st = EditorView.state view in
          let tr = EditorState.update st [ set_diagnostics st [] ] in
          List.exists
            (fun eff -> StateEffect.is eff set_diagnostics_effect)
            (Transaction.effects tr));

      check "open_lint_panel opens the panel" (fun () ->
          ignore (open_lint_panel view);
          El.find_first_by_selector ~root:(EditorView.dom view)
            (Jstr.v ".cm-panel-lint")
          <> None);

      check "close_lint_panel closes the panel" (fun () ->
          ignore (close_lint_panel view);
          El.find_first_by_selector ~root:(EditorView.dom view)
            (Jstr.v ".cm-panel-lint")
          = None);

      check "lint_keymap's F8 binding is wired through keymap" (fun () ->
          let synthetic =
            Jv.new'
              (Jv.get Jv.global "KeyboardEvent")
              [|
                Jv.of_string "keydown"; Jv.obj [| ("key", Jv.of_string "F8") |];
              |]
          in
          run_scope_handlers view (Brr.Ev.of_jv synthetic) "editor");

      (* [next_diagnostic] moves the selection to the next diagnostic, if
         one is reachable from the current selection; with the manual
         diagnostics set above it is, but this is exercised for its own
         sake (does it run and return a bool) rather than asserted on
         semantically, since reachability depends on the current
         selection and the diagnostic set at the time. *)
      check "next_diagnostic runs" (fun () ->
          let (_ : bool) = next_diagnostic view in
          true);

      report ())
