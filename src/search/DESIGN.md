# Cm_search

Bind `@codemirror/search` (node_modules/@codemirror/search/dist/index.d.ts).
Depends on Cm_state, Cm_view.

- `search : ?top:bool -> ?case_sensitive:bool -> ?literal:bool -> ?whole_word:bool -> ?regexp:bool -> ?create_panel:(editor_view -> Panel.t) -> ?scroll_to_match -> unit -> Extension.t`,
  `search_keymap`, `open_search_panel`, `close_search_panel`, `find_next`,
  `find_previous`, `select_matches`, `select_next_occurrence`,
  `select_selection_matches`, `replace_next`, `replace_all`, `goto_line`,
  `highlight_selection_matches : ?highlight_word_around_cursor -> ?min_selection_length -> ?max_matches -> ?whole_words -> unit -> Extension.t`,
  `module SearchQuery` (create ~search ?case_sensitive ?literal ?regexp ?replace ?whole_word; eq, valid, get_cursor),
  `get_search_query`, `set_search_query : StateEffectType`, `search_panel_open`,
  `module SearchCursor` and `module RegExpCursor` (next, done, value from/to),
  `module CharCategory`? no.
