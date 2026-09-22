# Cm_autocomplete

Bind `@codemirror/autocomplete` (node_modules/@codemirror/autocomplete/dist/index.d.ts).
Depends on Cm_state, Cm_view, Cm_language. Start from the previous
bindings for shape (`git show a5cd3d0:src/autocomplete/autocomplete.mli`
and `.ml`) but rename to CodeMirror's names:

- `module Completion` (create with label, display_label, detail, info,
  apply, type_, boost, section, commit_characters), `module CompletionContext`
  (state, pos, explicit, token_before, match_before, aborted, add_event_listener),
  `module CompletionResult` (create from ?to_ options ?validFor ?filter ?get_match ?update ?map ?commit_characters),
  `type completion_source = CompletionContext.t -> CompletionResult.t option Fut.t`,
  `complete_from_list : Completion.t list -> completion_source`,
  `complete_any_word`, `if_not_in`, `if_in`,
  `autocompletion : ?activate_on_typing -> ?override:completion_source list -> ?max_rendered_options -> ?default_keymap -> ?above_cursor -> ?icons -> ?add_to_options -> ?position_info -> ?compare_completions -> ?interaction_delay -> ?update_sync_time -> ?active_on_typing_delay -> ?option_class -> ?tooltip_class -> ?select_on_open -> unit -> Extension.t`,
  `completion_keymap`, `start_completion`, `close_completion`, `accept_completion`,
  `move_completion_selection`, `completion_status`, `current_completions`,
  `selected_completion`, `selected_completion_index`, `set_selected_completion`,
  `pick_completion`? (not exported), `insert_completion_text`,
  `close_brackets`, `close_brackets_keymap`, `delete_bracket_pair`,
  `insert_bracket`, `snippet`, `snippet_completion`, `snippet_keymap`,
  `clear_snippet`, `next_snippet_field`, `prev_snippet_field`, `has_next_snippet_field`,
  `has_prev_snippet_field`.
- Bind `RegExp` handling through `Jv` regexps (`Jv.t`) or brr's; do not
  reintroduce a RegExp module unless needed by `match_before`.
