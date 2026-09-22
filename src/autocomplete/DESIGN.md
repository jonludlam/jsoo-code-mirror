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

## Questions and friction

Things that turned out awkward, surprising, or worth a second look while
binding this package on top of `Cm_state`/`Cm_view`/`Cm_language`.

- **The promise-returning-source pattern is now the third hand-rolled copy,
  and this package needs it in *both* directions.** `Fut.map (fun v -> Ok
  (to_jv v))` then `Fut.to_promise ~ok:Fun.id` (src/view/cm_view.ml's
  `hover_tooltip`, src/lint/cm_lint.ml's `linter`, and now this file's
  `source_to_jv`, used by `if_in`/`if_not_in`/`autocompletion`'s `override`
  to hand an OCaml `completion_source` back to JavaScript) is copy-pasted
  for the third time with no new machinery. A helper earns its keep now:
  something like `Fut.to_promise_fn : ('a -> 'b Conv.t) -> ('a -> 'b Fut.t)
  -> Jv.t` (or, simpler and matching this codebase's `Conv.t` vocabulary,
  `Conv.async : 'b Conv.t -> ('a -> 'b Fut.t) Conv.t`, i.e. `Conv.callback`'s
  sibling for the async case) would collapse all three call sites to one
  line each. But this package *also* needs the reverse direction, which
  neither `Cm_view` nor `Cm_lint` needed: `complete_from_list`,
  `complete_any_word`, `if_in` and `if_not_in` all return a raw JavaScript
  `CompletionSource` (a function that may itself return its result
  synchronously *or* as a promise) that has to come back as a real OCaml
  `completion_source = CompletionContext.t -> CompletionResult.t option
  Fut.t` so it can be composed with `if_not_in` or dropped into `override`.
  There is no existing precedent for "wrap a JavaScript function that may or
  may not return a promise as an OCaml `'a -> 'b Fut.t`" anywhere in this
  library. The fix (`source_of_jv` in `cm_autocomplete.ml`) turned out
  simple once found — `Jv.Promise.resolve raw_result` normalizes a
  maybe-a-promise value into a real promise (it "joins" rather than
  double-wraps, per its own doc comment in `jv.mli`), so `Fut.of_promise`
  handles the rest — but finding it took longer than the wrapping direction
  did, and it deserves a name and a doc comment of its own
  (`Fut.of_maybe_promise`?) next to whatever collapses the other direction,
  since a source is exactly a case where both directions are needed on the
  same value.
- **`Completion.apply`'s `string | function` union, and where
  CONVENTIONS.md's rule stops covering it.** CONVENTIONS.md only names one
  union pattern explicitly (`boolean | "cover"` → polymorphic variant); a
  plain string vs. a callback isn't that shape, but nothing else in
  CONVENTIONS.md's "Unions" section addresses it either. The two cases *do*
  fall under the second rule ("a distinct JavaScript type gets a distinct
  OCaml type"), read generously: a bare replacement string and an arbitrary
  transaction-dispatching callback are different things to do, not two
  spellings of the same thing, so collapsing them (e.g. into `string` with a
  sentinel, or dropping the function case) would be the same kind of
  information loss the `cover` case warns about. `[ \`Text of string |
  \`Apply of ... ]` was the natural fit, and `Completion.info`'s `string |
  function` union (bound the same way, though further narrowed to only the
  synchronous, element-returning function case; see the `.mli`) confirms
  this is a recurring shape in this package specifically, not a one-off.
  Worth adding "a plain value vs. a callback that does something" as a named
  second case in CONVENTIONS.md's union rule, next to the boolean/string one.
- **`KeyBinding.t` has no `conv`, which every other generic-with-payload type
  in this library carries.** Binding `snippetKeymap` (a real
  `Facet<readonly KeyBinding[], readonly KeyBinding[]>`, unlike
  `Cm_view.keymap`'s opaque-output facet) needs a `KeyBinding.t Conv.t` to
  pass to `Facet.of_jv`/`Conv.list`, but `Cm_view.KeyBinding` only exposes
  `create` plus the bare `Jv.CONV` pair (`to_jv`/`of_jv`), not a `conv`
  value. Building one locally (`{ Conv.to_jv = KeyBinding.to_jv; of_jv =
  KeyBinding.of_jv }`) is a one-line workaround, but it means any package
  that needs a `'a Conv.t` for a type from another package has to know
  whether that package remembered to export `conv` — `Cm_view`'s `command`,
  `KeyBinding`, and a few others don't, since nothing inside `Cm_view`
  itself needed a `Conv.t` for them. Consistently exporting `conv` for every
  `Jv.CONV` type, even ones a package doesn't use as a `Conv.t` internally,
  would remove this class of one-off local reconstruction for whoever binds
  the next package.
- **`StateCommand` vs. `Command`, confirmed a second time.** Like
  `@codemirror/search` before it, this package has both flavors
  (`acceptCompletion`/`startCompletion` etc. are `Command`;
  `clearSnippet`/`nextSnippetField`/`prevSnippetField`/`deleteBracketPair`
  are `StateCommand`), and the same `command_of_jv` (`Jv.apply raw [|
  EditorView.to_jv view |]`, copied verbatim from `src/search/cm_search.ml`)
  invokes either uniformly, since an `editor_view` structurally has both
  `.state` and `.dispatch()`. Zero new friction, but it's now confirmed
  twice rather than once, which makes a strong case for `command_of_jv`
  becoming a shared helper (perhaps on `Cm_view.command` itself, e.g.
  `Cm_view.command_of_jv : Jv.t -> command`) instead of a private copy in
  every package that binds commands it didn't define.
- **`snippet`'s returned function and `Completion.apply`'s `` `Apply ``
  case are the same JavaScript shape but were not given the same OCaml
  type.** `snippet template` produces exactly `EditorView.t -> Completion.t
  option -> from:int -> to_:int -> unit`, and that is what you would want to
  hand to `Completion.create`'s `apply` — except `apply`'s `` `Apply ``
  case takes a non-optional `Completion.t`, matching the *interface*
  (`Completion.apply`'s callback parameter is `completion: Completion`, not
  nullable), while `snippet`'s returned function matches the *class*
  (`snippet`'s returned function's second parameter is `Completion | null`,
  since `snippet` is also called directly by the field-navigation commands
  with no completion in hand). Gluing the two together (as
  `snippetCompletion` does on the JavaScript side) needs a small adapter a
  caller would have to write themselves if they used `snippet` instead of
  `snippet_completion`; not a bug, but a place where two fixed-shorthand
  names in the same DESIGN.md entry turned out to want slightly different
  types for a real reason once bound from `index.d.ts` rather than guessed.
- **`CompletionContext.create`'s `explicit` argument has no default,
  unlike most everything else in this binding.** Every other `create` in
  this file (and most of `Cm_state`/`Cm_view`) is "everything optional
  except the couple of fields with no sensible default"; here `explicit` is
  a required positional-ish labeled argument straight from the JavaScript
  constructor's own required parameter, with no library-side default to
  fall back to. Consistent with the reference, but it stands out enough
  next to `Completion.create`'s wall of `?` that it is worth flagging so a
  reader doesn't go looking for `?explicit` and wonder why it is missing.
- **Testing `close_brackets` faithfully without Playwright meant calling
  `insert_bracket` directly rather than simulating a keystroke.** The
  extension's actual trigger is a real DOM `beforeinput`/composition event
  reaching `EditorView`'s own input-handling machinery, which is not
  something a synthetic event dispatched from OCaml can reliably reproduce
  (unlike `run_scope_handlers`, which `test/lint`'s keymap check drives with
  a synthetic `KeyboardEvent` because CodeMirror's key handling is a plain
  event listener). `insertBracket`'s own doc comment says it is exactly the
  function the extension calls internally on typed input, so
  `test/autocomplete/autocomplete.ml` calls it directly against a state
  carrying the `close_brackets ()` extension instead — a faithful test of
  the same logic, but a test of the function `close_brackets` delegates to
  rather than of typing through the DOM.
