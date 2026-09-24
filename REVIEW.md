# Binding all of CodeMirror: what it taught us

The reason for binding the whole library at once was not to have the
whole library. It was to find out whether the decisions taken while
adding four functions to the old bindings would still look right with
ten packages sitting on them. This is the answer.

The verdict: **the shape holds, and the exercise paid for itself.** Four
faults in the core were found by later packages and fixed before they
spread, one of my own additions turned out to be useless and was
removed, and one property of the package layout would have been a
silent, intermittent production bug if it had not been caught here.

## What the packages cost

| package | interface | tests |
|---|---|---|
| state | 654 lines | 52, under node |
| view | 709 | 11, browser |
| language | 901 | 8, browser |
| commands | 531 | 21, browser |
| autocomplete | 346 | 14, browser |
| lint | 126 | 10, browser |
| search | 222 | 14, browser |
| legacy-modes, theme-one-dark, codemirror | 90 | link test |

Roughly 3,600 lines of interface over 6,000 of implementation, and every
export of state, view, commands, autocomplete, lint and search is bound.
Language leaves the parser-generator internals alone, deliberately.

## Which packages, and which not

The package list was chosen, not derived, and the choice was not
complete. Checked against npm afterwards, CodeMirror's own first-party
packages are:

- **Bound**: state, view, language, commands, autocomplete, lint,
  search, legacy-modes, theme-one-dark, collab, lsp-client, and the
  `codemirror` meta-package.
- **Not bound**: `language-data`, the registry of language descriptions
  (our `LanguageDescription` is the type it supplies data for);
  `merge`, the side-by-side diff and merge view; and the seven
  `lang-*` grammar packages (javascript, html, css, markdown, python,
  json, xml), each of which exports one `LanguageSupport` and would all
  follow the same one-page pattern.

`collab` was missed on the first pass and only surfaced when the
bindings were compared against CodeMirror's own examples page, which
has a collaborative-editing example. Comparing against what upstream
documents, rather than against a list of one's own, is the cheap check
that would have caught it sooner. `lsp-client` was missed the same
way, and added when merlin-js, which talks to an OCaml language
server through it, moved onto these bindings.

## The conventions that held

- **One library and one bundle per npm package.** Each bundle sets one
  global, its package namespace, and aliases the other CodeMirror
  packages to shims reading the earlier globals. Nothing is loaded twice;
  a page that wants only an editor loads state and view and not the other
  eight. Proven in a browser: ten globals, one `EditorState` class.
- **One module per CodeMirror class, named as CodeMirror names it,
  positioned where CodeMirror positions it.** Nobody hit a case where
  this was wrong. It is also what makes the reference usable as the
  documentation, which is the reason the modules link to it rather than
  restating it.
- **`TransactionSpec` distinct from `Transaction`.** The change that
  started this. Six packages later, nothing has wanted them merged, and
  the separation is what lets `Compartment.reconfigure` return an effect
  that composes with other effects in one spec.
- **Commands as a bare function type.** `search` and `commands` both
  confirmed that CodeMirror's `Command` and `StateCommand` can share one
  `Cm_view.command`, and that ninety values of that type read fine when
  sectioned by odoc headings.
- **Converter-carrying generics.** `'a StateField.t`, `'a RangeSet.t`,
  `('i, 'o) Facet.t` carrying a `Conv.t` worked everywhere it was needed.
  The single-parameter ones share #17's `Tjv.CONV`, so every one has the
  same `to_jv`, `of_jv` and `conv`; a reader of the interface still cannot
  see which types are plain handles and which carry a converter. That is
  what abstraction is for.

## The faults it found

Every one of these was found by a package written after the decision, and
fixed in the core before the next package copied it.

1. **A `FacetReader` typed as an `Extension`.** It compiled, because
   everything is a JavaScript value underneath, and would have produced
   nonsense if passed to `Prec.highest`. This is the clearest evidence
   that in a binding library a wrong type usually still typechecks, and
   it is why the conventions now say that a distinct JavaScript type gets
   a distinct OCaml type even when it is only handed straight back.
2. **A union collapsed to a bool.** `touches_range` returned
   `boolean | "cover"`, and `"cover"` is precisely the case a caller who
   is dropping decorations wants. Now a variant, with a general rule.
   `lint` then extended the same rule to nullable booleans, and
   `autocomplete` to `string | function`.
3. **A state field's JSON hooks without the state.** Cheap to add,
   impossible to work around, and a field that resolves against a
   sibling needs it.
4. **Two of the conventions were simply wrong as written**, on when a
   trailing `unit` is needed and on whether another package's types are
   abstract. Both now state what is actually true.

## The fix that was wrong

I added `Conv.callback` because the view package's notes said a
combinator would cut repetition. Seven packages later it had **zero call
sites**: every real callback facet needs its own arity and labels, which
its fixed shape could not express, so each package hand-rolled a small
record instead. One agent reported having used it; it had not. It is
removed.

The lesson is narrow but worth keeping: a helper added on the strength of
one report, before a second case exists, is a guess. Three packages
independently hand-rolled the *same* future-to-promise wrapper, and that
one is real — it is listed below as work still to do.

## The finding that matters most

`@codemirror/commands` needs a library dependency on
`code-mirror.language` that **no OCaml signature mentions**. Its
JavaScript bundle reads the language package's global. Drop the
dependency and everything compiles; the indentation commands then fail
silently at run time, only on pages that happen not to load language for
another reason. It is now declared, with the reason written in both the
dune file and the interface.

This is a property of the per-package bundle design, so it deserves to be
stated plainly: **in this layout the OCaml dependency graph must mirror
the JavaScript one, including edges that carry no types.** Any package
added later has to be checked for this.

## What consuming it felt like

The sixteen example pages were written against the finished bindings by
people who had not written them, which is the only honest test of an
interface. Their verdict was that translating a CodeMirror recipe into
OCaml is direct: "flag lines over 40 characters and offer a fix",
"highlight the word under the cursor", "complete differently after an @"
all came out as the reference suggests, with no impedance mismatch.

Four things were unclear enough to cost someone time, and are now
documented where they were missed rather than in a guide nobody reads: a
view plugin's update returns unit and mutates in place, unlike a state
field's; `range` defaults to a point; a tag style's class needs the page
to supply the rule; and resolving a syntax tree at a token boundary
gives the node that ends there, which at position 0 is the document.

The package split also did what it was for. Of sixteen pages, one needs
only state, seven need state and view, five add one more package, and
only three pull the umbrella in, because they want `basic_setup` or the
theme.

## Still to do

- ~~A future-to-promise helper~~ and ~~`conv` on every bound type~~: both
  done, in `Cm_state.Async` and on `KeyBinding`.
- **`command_of_jv`** is duplicated in `search`, `autocomplete` and
  `commands`, and belongs in `view`.
- **Name the shapes the conventions do not cover**: a callback record
  like `StreamParser`, a write-only config field, a repeated callback
  type that earns an alias, and JavaScript subclassing (`LRLanguage`
  extends `Language`), which is a fourth relationship beyond the three
  the conventions name.
- **`state.mli` exists now, but `Conv`'s `invalid` and the `dep` type
  still read as plumbing.** Worth a second pass.

## What this says about the upstreaming branch

The commits prepared for `patricoferris/jsoo-code-mirror` were the
reason for all of this, and the exercise supports them. The transaction
spec split is the decision that most needed testing: six packages later
nothing has wanted the two merged, and it is what lets
`Compartment.reconfigure` compose with changes in one spec.
`EditorState.update` had no caller when it was added and now has one.
The placements — compartments in state, widget types as their own
module, line numbers as a function of the view package — match what the
whole library turned out to want.

It also found two gaps in upstream main that the branch does not
introduce but that anyone building on it meets next: a facet cannot be
defined, only wrapped; and `EditorState` cannot read a facet's value.

## Things that are CodeMirror, not us

Recorded so nobody debugs them twice. Completion closes when its view is
blurred and refuses to accept for the first 75ms after opening. A snippet
deactivates on reaching its last field, so neither direction is then
available. `replace_next` only replaces when the selection is already on
a match, and returns true either way. `select_next_occurrence` silently
collapses unless multiple selections are allowed. And `get_panel` can
essentially never return a panel, because it is keyed on a function value
and every conversion allocates a fresh closure — an argument against any
future API keyed on identity across the boundary.
