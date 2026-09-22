# Cm_language

Bind `@codemirror/language` (node_modules/@codemirror/language/dist/index.d.ts)
plus what the bundle also exposes: `__CM__lezer_common`, `__CM__lezer_highlight`,
`__CM__lezer_lr`. Depends on Cm_state and Cm_view (`open Cm_state`).

Fixed points:
- `module Language`, `module LRLanguage`, `module LanguageSupport`,
  `module LanguageDescription`, `module StreamLanguage` (with
  `StreamParser` as the record of callbacks it takes; bind `define :
  StreamParser.t -> StreamLanguage.t` where `StreamParser.t` is built with
  `StreamParser.create ~token ?start_state ?copy_state ?indent ?blank_line
  ?language_data ?token_table ()` over a `StringStream.t` module with
  `next`, `peek`, `eat`, `eat_while`, `match_`, `sol`, `eol`, `skip_to_end`,
  `current`, `indentation`, `pos`, `start`, `string`).
- `module HighlightStyle` with `define : ?scope -> ?all -> ?theme_type ->
  TagStyle.t list -> t`, `default_highlight_style`, `syntax_highlighting :
  ?fallback:bool -> HighlightStyle.t -> Extension.t`, `module Tag`/`Tags`
  exposing lezer's `tags` (`Tags.keyword`, `Tags.comment`, ...) as values.
- Free functions as package values: `language`, `syntax_tree`,
  `ensure_syntax_tree`, `syntax_parser_running`, `indent_unit`,
  `indent_on_input`, `indent_string`, `get_indent_unit`,
  `bracket_matching`, `match_brackets`, `fold_gutter`, `fold_keymap`,
  `code_folding`, `fold_service`, `folded_ranges`, `fold_effect`,
  `unfold_effect`, `fold_all`, `unfold_all`, `toggle_fold`,
  `highlight_active_line`? (no, that is view), `language_data_prop`,
  `sublanguage_prop`, `define_language_facet`, `indent_service`,
  `IndentContext` module, `TreeIndentContext`, `delimited_indent`,
  `continued_indent`, `flat_indent`, `get_indentation`, `indent_range`,
  `bidi_isolates`.
- lezer: `module Tree`, `module SyntaxNode` (name, from, to_, parent,
  first_child, last_child, child_after, child_before, next_sibling,
  prev_sibling, resolve, resolve_inner, enter, get_child, get_children,
  type_), `module NodeType`, `module NodeProp` minimal, `module Parser`
  minimal. Keep these to what `Cm_language` itself returns or takes.
- Record what you leave out under "Not bound".

## Questions and friction

- **`Conv.t`-carrying types work fine for lezer's tree types, but only by
  keeping them monomorphic, not generic.** `Tree.t`/`SyntaxNode.t`/
  `NodeType.t` are plain `= Jv.t` forward types with ordinary functions, the
  same as `Cm_state.Extension.t` or `Cm_state.Transaction.t` — none of them
  needed to carry a `Conv.t`, because nothing generic (a `StateField`, a
  `RangeSet`, a facet output) is ever parameterized *by* a `Tree.t` or a
  `SyntaxNode.t` in this package. `NodeProp<T>` is the one place lezer is
  genuinely generic (a prop's value type varies per instance), and there the
  `Conv.t` style does not fit cheaply: a `Conv.t`-carrying `'a NodeProp.t`
  would need every consumer of a *predefined* prop (`closedBy`, `group`, the
  library's own `languageDataProp`) to also be handed the matching `Conv.t`,
  which is more ceremony than the alternative taken here — `NodeProp.t` is a
  flat, non-generic `Jv.t` handle, and each predefined prop gets its own
  typed convenience reader on `NodeType` (`closed_by_names`, `is_isolate`,
  ...) instead. So: the style scales to "return a fixed JS class", which
  covers all of lezer's tree surface; it does not have a cheap answer for "a
  container generic in an unbounded, per-instance-fixed payload type", and
  this package sidesteps rather than solves that case.
- **`StreamParser`'s callback record needed something the conventions don't
  name: an escape-hatch identity cast for opaque state, not `Conv.t`.**
  JavaScript's `StreamParser<State>` is generic in a `State` the tokenizer
  thread through `token`/`startState`/`copyState`/`indent`/`blankLine`, but
  that `State` is *never* read back into OCaml except by those same
  callbacks, and it never crosses into a `Facet`/`StateField`/effect, so it
  is not "a generic container" in the `Conv.t` sense described in
  CONVENTIONS.md — there is no encode/decode pair to speak of, only "smuggle
  an arbitrary OCaml value through a JavaScript object and get the same
  value back." `StreamParser.create`'s `'state` is an ordinary,
  call-site-scoped type variable (like any polymorphic function argument);
  the JavaScript-facing plumbing uses `Jv.Id.to_jv`/`Jv.Id.of_jv` (brr's
  identity-cast `Jv.CONV` implementation) to stash and retrieve it. This
  works cleanly, but CONVENTIONS.md's "carry a `Conv.t`" framing does not
  mention this shape at all, and a reader would not find it by generalizing
  from `Cm_state`/`Cm_view`'s facet-of-function pattern (`Conv.callback`),
  which is for a *function value itself* becoming a facet's payload, not for
  an opaque non-`Jv.t` value threaded between several callbacks of one
  record. Also: `copyState`'s JavaScript default (a shallow object copy)
  is unsafe against an opaque js_of_ocaml representation (it special-cases
  arrays and otherwise does a `for...in` property copy, which silently
  produces `{}` for, say, an unboxed int state), so this binding overrides
  the default to plain identity when `copy_state` is omitted — correct only
  because OCaml state is conventionally treated as immutable/functional, a
  precondition the JavaScript interface itself never states.
- **`Conv.callback` (added per `Cm_view`'s own friction notes) turned out to
  still not be used, here either.** Its signature, `arity:int -> ('a -> 'b
  -> 'c) -> 'a t`, is shaped for exactly one curried arity (2), but every
  callback-valued facet or option in this package needs a different arity
  (1, 2, or 3) and/or labelled arguments (`~pos`, `~line_start`) baked into
  the wrapper. `indent_service`, `fold_service`, `tag_highlighter`'s
  `?scope`, and `StreamParser`'s five callback fields are all hand-rolled
  `Conv.t` records or raw `Jv.callback` calls, the same as `Cm_view.mli`'s
  `panel_constructor_conv`/`input_handler_conv`. `Cm_view`'s own DESIGN.md
  credits `Conv.callback` with "removing the repetition," but grepping
  `cm_view.ml` shows no actual call site — this package's experience
  confirms that note describes an aspiration rather than a combinator that
  fits real call sites; CONVENTIONS.md should either drop the claim or
  broaden `Conv.callback` to a family of arities/label shapes.
- **`foldState` is not bound; `folded_ranges` reads the same
  information.** `@codemirror/language` exports a ready-made
  `StateField<DecorationSet>`, which `StateField.of_jv` could wrap, but
  nothing here needed the field itself.
- **Two more instances of the "declare something ahead of its natural
  home" trick, beyond the ones DECISIONS.md already calls out.**
  `indent_result` (JavaScript's `number | null | undefined` for
  `indentService`) and `match_result`/`doc_range` (`{from, to}` pairs,
  folded to plain `int * int` tuples throughout rather than given a
  record) are both exactly the "a callback's return shape needs a name"
  pattern `change_by_range_result` and `mouse_selection_style` already
  established; naming this pattern once in CONVENTIONS.md (rather than
  leaving each package to rediscover "polymorphic variant for a 3-way
  JavaScript union" and "plain tuple for a `{from,to}` object") would have
  saved a design decision here.
- **Subclassing (`LRLanguage`/`StreamLanguage` extend `Language`) is a
  fourth relationship the conventions don't name, next to "distinct type,
  explicit conversion" and "forward type."** Both are bound as their own
  abstract types (per "a distinct JavaScript type gets a distinct OCaml
  type"), each with a `to_language` identity-cast escape hatch, rather than
  either (a) collapsing them into `Language.t` (which would have made
  `StreamLanguage.define`'s fixed `StreamLanguage.t` return type impossible)
  or (b) duplicating every `Language` accessor on each subclass. This reads
  fine once written, but nothing in CONVENTIONS.md says "a JavaScript
  subclass becomes its own type plus an upcast," so it was a judgment call
  rather than a rule application; a future package binding a deeper
  hierarchy (lezer's own `Tree`/`TreeBuffer`, or a three-level CodeMirror
  subclass chain) would benefit from this being named.
- **The `.mli` preamble's "reference entry" link is occasionally ambiguous
  between two packages' documentation sites.** This package straddles
  `codemirror.net/docs/ref/#language.*` and `lezer.codemirror.net/docs/ref/#common.*`/
  `#highlight.*`/`#lr.*` — CONVENTIONS.md's one-line preamble instruction
  assumes a single reference site per bound module, which holds for every
  package bound so far but not for this one; each module's preamble names
  which of the four sites it is quoting, which the convention does not
  ask for but which turned out to be necessary for the preamble to be
  useful.
