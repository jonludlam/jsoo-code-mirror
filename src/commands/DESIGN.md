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

## Questions and friction

- **A package that's ~90 values of the same `command` type reads fine in
  OCaml, once it's sectioned.** Nothing about `cmd "cursorCharLeft"` /
  `cmd "cursorCharRight"` / ... is individually interesting, and a flat,
  unsectioned `.mli` of 90 one-line `val x : command`s would be a wall
  nobody reads top to bottom. The odoc `{1 ...}` headings the task asked
  for genuinely fix this: `{1 Cursor motion}` next to `{1 Selection}` next
  to `{1 Deletion}` turns "undifferentiated list" into "table of contents",
  and CodeMirror's own naming (`cursor_*` / `select_*` pairs, `delete_*`,
  `*_line`) maps onto the headings almost mechanically - the grouping
  decision was easy precisely because the JavaScript names already sort
  themselves by prefix. The one place the headings *don't* help is
  skimming the `.ml`: `cmd "cursorCharLeft"` one-liners are just as
  undifferentiated there, but nobody reads the `.ml` for the API shape -
  the `.mli` is the reference, exactly as CONVENTIONS.md says.
- **`command` as a bare function type (`editor_view -> bool`) caused zero
  trouble, and confirms `@codemirror/search`'s finding at full package
  scale.** Every one of this package's ~90 commands is a JavaScript
  `Command` or a `StateCommand` - two different TypeScript parameter
  shapes - and `command_of_jv`'s `Jv.apply raw [| EditorView.to_jv view |]`
  invokes either uniformly because both destructure a `{state, dispatch}`-
  shaped object and `editor_view` structurally has both. Unlike `search`
  (which had exactly one `StateCommand`/`Command` pair worth footnoting),
  here the *entire* package is that mix, so the honest documentation move
  was one sentence in the `.mli` preamble instead of a per-value note - a
  package this uniformly StateCommand-heavy doesn't need repeating the
  same caveat ninety times.
- **A whole-package dependency can be real at the JavaScript level with
  zero trace in the `.mli`'s types.** No value in `cm_commands.mli`
  mentions `Cm_language`; `indent_more`/`indent_less`/
  `insert_newline_and_indent`/`indent_selection`/`indent_with_tab` are all
  plain `command`s. But `@codemirror/commands`'s own JS bundle imports
  `getIndentUnit`/`indentUnit`/`IndentContext`/`getIndentation` from
  `@codemirror/language`, and `js/build.sh`'s alias scheme turns that
  import into a shim reading `globalThis.__CM__language` - so at run time,
  calling `indent_more` before `code-mirror.language`'s bundle has executed
  silently produces a JavaScript exception (caught here only because the
  test harness wraps each check in `try ... with _ -> false`, so it read as
  a mundane check failure, not a crash). The fix is exactly what the seed
  `dune` file already had - `(libraries brr cm_state cm_view cm_language)`
  - which was tempting to "clean up" away since nothing in the `.ml`
    references `Cm_language`, and doing so *does* still build
    (`dune build src/commands` alone is silent either way): the dependency
    only manifests as a browser-test failure, not a compile error, which
    makes it exactly the kind of thing a future pass could regress without
    noticing. Worth a line in CONVENTIONS.md: an OCaml-level `libraries`
    dependency can exist purely to link a JS bundle another bundle's shim
    reads a global off, with no corresponding value or type anywhere in
    the depending module's signature.
- **`Conv.callback`, added in `Cm_state` for exactly this shape, had no
  real caller before this package.** `invertedEffects : Facet<(tr:
  Transaction) => readonly StateEffect<any>[], ...>` is a facet whose
  value is a function, the same shape `Cm_view`'s `change_filter`/
  `transaction_filter` hand-roll; using it here (`Conv.callback ~arity:1`)
  worked on the first try, but it needed the same
  wrap-argument/wrap-result boilerplate those already write by hand rather
  than saving any of it - the combinator wraps `Jv.callback` but still
  leaves the caller converting each argument and the result explicitly, so
  it is a documentation aid (this *is* the sanctioned way to do it) more
  than a code-reduction one. `src/view/DESIGN.md`'s wish for a
  `Conv.fn1`/`Conv.fn2` that wraps the argument and result conversions too
  still stands.
- **`isolate_history` and `inverted_effects` wrap values CodeMirror
  defines,** with `AnnotationType.of_jv` and `Facet.of_jv`: a fresh
  `AnnotationType.define` would not have `isolateHistory`'s JavaScript
  identity.
- **`history_field` stays a bare handle.** `StateField.of_jv` could wrap
  it, but its value is CodeMirror's private history state, which has no
  OCaml type to convert to, and `EditorState.to_json`/`from_json` don't
  take the per-field dictionary that is the only place JavaScript itself
  threads it through.
- **Environment, not design: a corrupted shared `~/.cache/dune` entry
  (107GB, written concurrently by every agent building in this tree) made
  every `dune build` touching `src/language` fail with a spurious
  `I/O error: ... No such file or directory` for a file that plainly
  existed on disk, for over ten minutes, independent of whether another
  build was running at that moment.** `dune build --force` did not help
  (the missing step is dune's cache-backed copy of the source file into
  `_build/default/...`, not a stale rule result); `DUNE_CACHE=disabled`
  for the one invocation did. Not a finding about this package, but worth
  recording somewhere Claude instances working in this tree concurrently
  will see it, since `--force` looking like the obvious fix and silently
  not being one cost real time.
