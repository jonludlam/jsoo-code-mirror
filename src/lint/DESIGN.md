# Cm_lint

Bind `@codemirror/lint` (node_modules/@codemirror/lint/dist/index.d.ts).
Depends on Cm_state, Cm_view. Previous shape: `git show a5cd3d0:src/lint/lint.mli`.

- `module Diagnostic` (create ~from ~to_ ~severity ~message ?source ?mark_class ?actions ?rendered_message; readers), `type severity = Hint | Info | Warning | Error`,
  `module Action` (create ~name ~apply),
  `linter : ?delay:int -> ?need_refresh:(view_update -> bool) -> ?mark_class -> ?tooltip_filter -> ?hide_on -> ?auto_panel:bool -> (editor_view -> Diagnostic.t list Fut.t) -> Extension.t`,
  `lint_gutter : ?hover_time:int -> ?mark_class -> ?tooltip_filter -> unit -> Extension.t`,
  `lint_keymap`, `open_lint_panel`, `close_lint_panel`, `next_diagnostic`,
  `previous_diagnostic`, `set_diagnostics : EditorState.t -> Diagnostic.t list -> TransactionSpec.t`,
  `set_diagnostics_effect`, `diagnostic_count`, `for_each_diagnostic`,
  `force_linting`.
