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

## Questions and friction

Things that turned out awkward, surprising, or worth a second look while
binding this package on top of `Cm_state`/`Cm_view`.

- **The iterator-shaped cursors fit better than expected, once `Jv.It` was
  found.** `SearchCursor`/`RegExpCursor`'s `next(): this` is unusual (the
  call mutates and returns the same object, which also serves as its own
  `IteratorResult` since `.done`/`.value` already live on it), but that is
  *exactly* what `Jv.It.next`/`result_done`/`get_result_value` already
  assume — they just call `.next()` by name and read `.done`/`.value` off
  whatever comes back, with no requirement that it be a fresh object. So
  `next : t -> match_ option` is `Jv.It.next` plus one `if done then None`
  check, and `fold`/`iter` are literally `Jv.It.fold`. `next_overlapping`
  (only on `SearchCursor`) doesn't fit `Jv.It.next`'s hardcoded `"next"`
  method name, so it calls `Jv.call t "nextOverlapping" [||]` directly and
  reuses the same done/value decoding. None of this needed `Obj.magic` or a
  bespoke protocol; the only design choice was dropping `[Symbol.iterator]`
  itself (superseded by `fold`/`iter`) and not exposing `done`/`value` as
  separate accessors, since every consumer wants them together as one
  `option`.
- **`SearchQuery.getCursor`'s return type has no CodeMirror class name.**
  JavaScript types it as a bare `Iterator<{from, to}>`; at runtime the
  object is either a real `SearchCursor` or a real `RegExpCursor` (chosen
  by the query's `regexp` flag), but the *type* deliberately erases which,
  and drops `RegExpCursor`'s capture groups even when the runtime object
  has them. Rather than inventing a module for an anonymous interface (or
  leaking the regexp/non-regexp choice into the return type), `get_cursor`
  returns `SearchCursor.t` — every field `SearchCursor.next` reads
  (`from`/`to`/`done`) is present on both real classes, so this is safe,
  and it matches what the reference itself exposes. A caller who knows a
  query is a regexp query and wants capture groups has to fall back to
  constructing a `RegExpCursor.t` directly instead of going through
  `SearchQuery.get_cursor`.
- **Commands-as-values read fine, and `StateCommand` vs `Command` turned
  out to be a non-distinction at this boundary.** `find_next : command`,
  `replace_all : command`, etc. all read naturally at call sites
  (`find_next view`), same as the fixed `Cm_view.command` design intends.
  JavaScript's `StateCommand` (`selectNextOccurrence`,
  `selectSelectionMatches`) is typed differently from `Command`
  (destructuring `{state, dispatch}` rather than taking a whole
  `EditorView`), but since every value this package needs to call a
  command against is already an `editor_view` — which structurally has
  both `.state` and `.dispatch()` — a single `command_of_jv : Jv.t ->
  command` wrapper (`Jv.apply raw [| EditorView.to_jv view |]`) invokes
  either kind identically. Nothing in the exported surface forces the two
  apart, so this package doesn't bind a separate `state_command` type;
  worth confirming this holds if a future package's `StateCommand` is ever
  called with something that *isn't* a full `EditorView`.
- **`replace_next` and `select_next_occurrence` both return `true` far
  more often than they change anything, which the type `command = editor_view
  -> bool` doesn't hint at.** `replace_next` only replaces text when the
  selection is already sitting exactly on a match; otherwise it just moves
  the selection there (like `find_next`) and still returns `true`. A
  caller who wants "replace the next match" as one step has to call
  `find_next` first, exactly as the search panel UI does over two
  keypresses. This isn't a binding gap — the JavaScript function has the
  same behavior — but `bool` reads as "did something happen" when it
  really means "did I make progress towards the query" and cost real time
  to rediscover while writing `test/search/search.ml`.
- **`select_next_occurrence`/multi-selection is invisible unless
  `EditorState.allowMultipleSelections` is on, and nothing about the
  binding says so.** `select_next_occurrence`'s command still returns
  `true` and even builds a transaction with two selection ranges when
  multi-selection is off; `EditorState.update`/state construction silently
  collapses the selection back to one range because
  `allow_multiple_selections` (bound in `Cm_state`) defaults to `false`.
  Confirmed by capturing the dispatched `Transaction.t` directly: its
  `selection` field had both ranges, but `Transaction.state`'s selection
  had only one. `search`'s `Extension.t` does not turn this facet on for
  you, matching upstream (which also expects the embedder to opt in), but
  a caller who adds `search ()` and calls `select_next_occurrence` without
  also enabling `allow_multiple_selections` gets a command that reports
  success and silently does nothing beyond the first range. Worth a
  one-line pointer from `select_next_occurrence`'s doc comment to
  `EditorState.allow_multiple_selections`, which this file's `.mli` now
  has.
- **`RegExpExecArray`'s numbered captures decode cleanly as `string option
  array`; its named captures (`.groups`) and `.index`/`.input` do not fit
  this package's existing `Conv` vocabulary and are dropped.** The
  positional capture groups are a real JavaScript array (`Jv.to_array`
  handles it directly, `undefined` elements become `None` via
  `Jv.is_none`), but `.groups` is a plain object keyed by capture name,
  and nothing in `Cm_state.Conv` or this package converts an arbitrary
  JavaScript object to an association list — the same gap `Cm_state`'s own
  "Not bound" list calls out for `combineConfig`. Adding it just for this
  one field felt like scope creep; noted in the `.mli`'s own "Not bound"
  section instead.
- **The `EditorState | Text` union on `SearchQuery.getCursor` reused the
  `set_tab_focus_mode`-style polymorphic variant from `Cm_view` rather than
  inventing anything new.** `[ \`State of EditorState.t | \`Doc of Text.t
  ]` is the only place in this package that needs a union of two distinct
  object types (as opposed to `Cm_view`'s bool-vs-int union); the existing
  precedent applied directly with no new convention needed.
