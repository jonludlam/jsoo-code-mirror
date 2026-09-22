# How these bindings are shaped

One goal: someone with the CodeMirror reference open should be able to
guess the OCaml name of anything, and vice versa.

## Packages

One dune library per CodeMirror npm package, each shipping the bundle for
that package and nothing else:

| npm package              | dune library               | OCaml module        | global               |
|--------------------------|----------------------------|---------------------|----------------------|
| @codemirror/state        | code-mirror.state          | Cm_state            | __CM__state          |
| @codemirror/view         | code-mirror.view           | Cm_view             | __CM__view           |
| @codemirror/language     | code-mirror.language       | Cm_language         | __CM__language, __CM__lezer_{common,highlight,lr} |
| @codemirror/commands     | code-mirror.commands       | Cm_commands         | __CM__commands       |
| @codemirror/autocomplete | code-mirror.autocomplete   | Cm_autocomplete     | __CM__autocomplete   |
| @codemirror/lint         | code-mirror.lint           | Cm_lint             | __CM__lint           |
| @codemirror/search       | code-mirror.search         | Cm_search           | __CM__search         |
| @codemirror/legacy-modes | code-mirror.legacy-modes   | Cm_legacy_modes     | __CM__legacy_modes   |
| @codemirror/theme-one-dark | code-mirror.theme-one-dark | Cm_theme_one_dark | __CM__theme_one_dark |
| codemirror               | code-mirror                | Code_mirror         | __CM__codemirror     |

`Code_mirror` re-exports every module (`module State = Cm_state`, ...) and
binds `basicSetup`/`minimalSetup`; depending on it links everything, as the
`codemirror` package does. Depend on the sub-libraries for a smaller page.

Each library's `dune` builds `bundle.js` from `js/entries/<name>.js` with
`js/build.sh` (profile `with-bundle`, promoted, so users need no node).
The bundle sets one global, the package namespace; the OCaml side reads
`Jv.get (Lazy.force pkg) "EditorState"`. Never add ad hoc globals.

## Modules

- One OCaml module per CodeMirror class, interface or exported function
  group, named exactly as CodeMirror names it: `EditorState`,
  `TransactionSpec`, `WidgetType`, `Compartment`. Free functions of a
  package are values of the package module: `Cm_view.line_numbers`,
  `Cm_view.keymap`, `Cm_commands.default_keymap`.
- Values, labels and record fields are snake_case: `set_state`,
  `doc_changed`, `?class_name`, `scroll_into_view`. Nothing camelCase.
- Every JS-backed type is `type t` with `include Jv.CONV with type t := t`
  (brr's convention) so there is always an escape hatch, and `Jv.t` never
  appears otherwise in a signature a user writes against.
- Every module has an `.mli`. Its preamble names the CodeMirror entry it
  binds, e.g. `(** {{:https://codemirror.net/docs/ref/#state.Compartment}
  state.Compartment} *)`, and says only where the OCaml shape differs.
  The reference is the documentation.
- Optional JS config fields are optional arguments. A trailing `unit` is
  needed whenever an optional argument is not followed by a positional
  one (OCaml's warning 16), which includes the case where only labelled
  arguments follow.
- Across packages, another package's types are abstract even though they
  are all `Jv.t` inside its own file: convert explicitly with `to_jv` and
  `of_jv` rather than assuming a bare value will typecheck.

## Typed values

CodeMirror is generic (`StateField<T>`, `Facet<In, Out>`, `RangeSet<T>`).
The OCaml side is too, carrying a converter:

    type 'a Conv.t = { to_jv : 'a -> Jv.t; of_jv : Jv.t -> 'a }

- `Cm_state.Conv` provides `jv`, `int`, `bool`, `string`, `jstr`, `list`,
  `option`, and every bound type exposes `val conv : t Conv.t`.
- Generic containers are `'a t`: `'a StateField.t`, `'a RangeSet.t`,
  `'a Range.t`, `('i, 'o) Facet.t`, `'a StateEffectType.t`. There is no
  `ty`. `StateEffect.t` is an effect instance; `StateEffectType` is its
  own module, as in CodeMirror.
- Definition functions take one converter: `StateField.define : 'a Conv.t
  -> create:... -> update:... -> 'a t`, `StateEffectType.define : ?map:...
  -> 'a Conv.t -> 'a t`, `Facet.define : ?combine:... -> 'i Conv.t -> 'o
  Conv.t -> ('i, 'o) t`.
- A converter that cannot decode raises `Invalid_argument` with the
  module name. Never `assert false`.

## Unions, and what the types must not allow

Everything is `Jv.t` underneath, so a wrong binding usually compiles.
Two rules follow:

- A JavaScript union of a boolean and a string constant (`boolean |
  "cover"`) becomes a polymorphic variant, never a `bool`.
- A distinct JavaScript type gets a distinct OCaml type, even when it is
  only ever passed straight back to the library. Giving it the type of
  something structurally similar (a `FacetReader` typed as an
  `Extension`) buys nothing and lets meaningless code typecheck.

## Requests and results

`TransactionSpec` is what you ask for; `Transaction` is what the state
made of it. `EditorView.dispatch` takes specs, `EditorState.update` turns
specs into a transaction, fields and listeners receive transactions.
Anything that returns a `StateEffect.t` (`Compartment.reconfigure`,
`StateEffectType.of_`) is meant to be composed into a spec.

## Cross-references between modules

Where a module needs a type declared later in the same interface (for
example `EditorViewConfig` mentions `EditorView.t`), declare a forward
abstract type at the top of the `.mli` (`type editor_view`) and equate it
in the later module (`module EditorView : sig type t = editor_view ...`).
Do not add a `Types` module.

This works because a handful of central types are referenced from
everywhere and the rest is a tree; it is not a general answer to mutual
recursion, and a package that needs one should say so rather than
contorting. A record type declared above its natural home for the same
reason (a callback's return shape) is the same trick: put it with the
forward types and say what it is for.

## Examples

`examples/<name>/` holds one page per feature, built with the same
`dune` shape as the existing ones. An example exists for every module
that does something visible; the browser tests drive them.
