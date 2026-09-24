open Cm_view
open Example_check

let () =
  (* the linter runs after its delay, 750ms by default *)
  after 1500 @@ fun () ->
  let view = Lint.view in
  check "the regular expression is flagged" (fun () ->
      Cm_lint.diagnostic_count (EditorView.state view) = 1);
  check "it is underlined, and marked in the gutter" (fun () ->
      by_class view "cm-lintRange-warning" <> []
      && by_class view "cm-lint-marker-warning" <> []);
  report ()
