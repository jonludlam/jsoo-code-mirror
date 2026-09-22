# Cm_commands

Bind `@codemirror/commands` (node_modules/@codemirror/commands/dist/index.d.ts).
Depends on Cm_state, Cm_view, Cm_language. Almost everything is a
`Cm_view.command` (`editor_view -> bool`) or a `KeyBinding.t list`:

- keymaps as values: `default_keymap`, `standard_keymap`, `emacs_style_keymap`,
  `history_keymap`, `indent_with_tab` (a `KeyBinding.t`).
- `history : ?min_depth:int -> ?new_group_delay:int -> ?join_to_event:(Transaction.t -> bool -> bool) -> unit -> Extension.t`,
  `history_field`, `undo`, `redo`, `undo_selection`, `redo_selection`,
  `undo_depth`, `redo_depth`, `is_isolate_history : AnnotationType`,
  `invert_changes`? (`invertedEffects` facet).
- Every cursor/selection/deletion/line command as a `command` value with
  its snake_case name: `cursor_char_left`, `select_line_down`,
  `delete_group_backward`, `insert_newline_and_indent`, `indent_more`,
  `toggle_comment`, `toggle_block_comment`, `line_comment`, ... The
  d.ts lists them all; bind all of them, they are one line each.
- `insert_tab`, `insert_newline`, `simplify_selection`, `select_all`,
  `cursor_syntax_left`, `select_parent_syntax`, `move_line_up`, `copy_line_down`,
  `delete_line`, `transpose_chars`, `split_line`, `cursor_matching_bracket`.
- `comment_keymap`, `comment_tokens` facet? (`CommentTokens` is language data; skip).
