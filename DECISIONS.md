# Decisions taken while binding the whole library

The point of binding all of CodeMirror at once was to find out whether
the conventions hold at full size. This records what the friction found
in each package led to, so a reviewer can see which choices were tested
rather than assumed. Each package's own DESIGN.md has the raw friction.

## From @codemirror/state

**Fix: `Facet.reader` must not be an `Extension.t`.** JavaScript's
`FacetReader` is unrelated to `Extension`; typing it as one compiles only
because everything is `Jv.t` underneath, so passing a reader to
`Prec.highest` would produce nonsense instead of a type error. It gets a
`FacetReader.t` of its own, and `EditorState.facet` and `Facet.compute`
accept either. This is the clearest evidence in the exercise that "every
type is `Jv.t` underneath" makes wrong bindings compile: worth stating in
the conventions so later packages do not repeat it.

**Fix: `ChangeDesc.touches_range` keeps the `cover` case.**
JavaScript returns `boolean | "cover"`; collapsing it to `bool` loses
the one piece of information a decoration-dropping caller actually wants.
Now `[ `No | `Touches | `Covers ]`. General rule for the rest of the
library: a JavaScript union of a boolean and a string constant becomes a
polymorphic variant, never a bool.

**Fix: `StateField.define`'s `?to_json`/`?from_json` take the state.**
JavaScript passes it, and strategies that resolve against a sibling field
need it. Cheap to add, impossible to work around.

**Accepted: the converter-carrying types share #17's `Tjv`.**
`'a StateField.t`, `'a RangeSet.t` and the other single-parameter
containers carry their `Conv.t` beside the JavaScript handle, while
`Extension.t` and `Transaction.t` stay bare handles. A reader of the
interface cannot tell which is which. That is what abstraction is for,
and the alternative (a converter argument at every use site) is worse.
They use the `Tjv` module from patricoferris/jsoo-code-mirror#17 and its
names (`to_jv`, `of_jv`, `conv`, `any`), plus `conv_of` for the
container's own converter; `Facet` has two converters and keeps its own
record. Unlike #17, `StateEffectType` (the typed definition) stays
separate from `StateEffect.t` (the untyped instance), as in CodeMirror:
#17's single type lets an instance pass where a definition is expected,
and forces `any` on every list of effects.

**Accepted: `RangeSet.eq` compares one set to one set.** JavaScript's
static compares groups of sets in one pass for the view layer's benefit.
Anyone needing that is writing a view internal, not using these bindings.

**Accepted, with a note in CONVENTIONS.md: forward types do not scale
arbitrarily.** They work here because a handful of types (`editor_state`,
`transaction`, `state_effect`, `'a state_field`, `annotation`, facets)
are referenced from everywhere and everything else is a tree. A package
with real mutual recursion would need recursive modules instead. Also:
declaring a record ahead of its home module, as `change_by_range_result`
does, is the same trick and should be called out where it happens.
