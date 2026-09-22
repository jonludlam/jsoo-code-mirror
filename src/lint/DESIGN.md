# Cm_lint

Bind `@codemirror/lint` (node_modules/@codemirror/lint/dist/index.d.ts).
Depends on Cm_state, Cm_view. Previous shape: `git show a5cd3d0:src/lint/lint.mli`.

- `module Diagnostic` (create ~from ~to_ ~severity ~message ?source ?mark_class ?actions ?rendered_message; readers), `type severity = Hint | Info | Warning | Error`,
  `module Action` (create ~name ~apply),
  `linter : ?delay:int -> ?need_refresh:(view_update -> bool) -> ?mark_class -> ?tooltip_filter -> ?hide_on -> ?auto_panel:bool -> (editor_view -> Diagnostic.t list Fut.t) -> Extension.t`,
  `lint_gutter : ?hover_time:int -> ?mark_class -> ?tooltip_filter -> unit -> Extension.t`,
  `lint_keymap`, `open_lint_panel`, `close_lint_panel`, `next_diagnostic`,
  `previous_diagnostic`, `set_diagnostics : EditorState.t -> Diagnostic.t list -> TransactionSpec.t`,
  `set_diagnostics_effect`, `diagnostic_count`, `for_each_diagnostic`,
  `force_linting`.

## Questions and friction

- **`Fut.t`-returning sources bound cleanly, with zero new machinery.**
  `linter`'s source is exactly the same shape as `Cm_view.hover_tooltip`'s
  (`editor_view -> ... -> 'a option Fut.t` there, `editor_view ->
  Diagnostic.t list Fut.t` here): `Fut.map (fun v -> Ok (to_jv v))` then
  `Fut.to_promise ~ok:Fun.id`. Copying that pattern verbatim was the whole
  job; a `Conv`-level or `Fut`-level helper for "wrap an OCaml
  `'a -> 'b Fut.t` as a JavaScript function returning a Promise" would
  remove the copy, since this is now the second package to hand-roll it.
- **`Severity` is a plain string union with no JavaScript-side object**,
  unlike `MapMode`/`Direction`/`BlockType`/`CharCategory`, which are all
  (compile-time) int enums this library reads/writes as bare integers. It
  still needed hand-written `to_string`/`of_string` instead of the
  `_to_int`/`_of_int` pair the precedent enums use. DESIGN.md's shorthand
  wrote it as a bare `type severity = ...`; this file instead gives it a
  `module Severity` for consistency with the other enumerations, even
  though, unlike them, nothing in CodeMirror ever hands out or expects a
  `Severity` object — CONVENTIONS.md doesn't say whether a plain enum with
  no runtime JS presence earns a module of its own or stays a bare type.
- **The `Diagnostic` record itself wanted nothing beyond plain field
  get/set** (`Jv.Int`/`Jv.Jstr` accessors, `Jv.set_if_some` for the
  optionals): no unions, no nested generics, nothing `Conv.t`-worthy.
  The only wrinkle is `rendered_message` (`renderMessage`) and, by
  extension, `Action.apply`: both are write-only function fields with no
  sensible reader (a JavaScript function can't be inspected once wrapped),
  which is the same situation `Cm_view.WidgetType`'s callbacks are in, but
  nothing in CONVENTIONS.md names "config fields that are functions get a
  writer and no reader" as a pattern, so each package has re-discovered it
  independently.
- **`DiagnosticFilter` is shared by two config knobs on two different
  functions** (`linter`'s `marker_filter`/`tooltip_filter`, `lint_gutter`'s
  same two), so it became a top-level `diagnostic_filter` type alias, the
  same move `Cm_view.command` makes. CONVENTIONS.md documents the forward
  abstract-type trick for cross-referenced classes but says nothing about
  when a repeated callback shape earns its own named alias versus being
  written out at each use site; this one was an easy call only because
  `command` already set the precedent.
- **DESIGN.md's own shorthand (`?mark_class` on `linter`/`lint_gutter`)
  doesn't match `index.d.ts`.** The actual config field is `markerFilter`
  (a `DiagnosticFilter`, i.e. `marker_filter` here), unrelated to
  `Diagnostic`'s own `markClass` string field bound as `?mark_class` on
  `Diagnostic.create`. Bound from `index.d.ts` as the more authoritative
  source per the task instructions; worth a fix in DESIGN.md so a future
  reader doesn't wire the wrong optional argument.
- **`hideOn`'s `boolean | null` return collapsed to `bool option`**
  (`None` is JavaScript's `null`, "fall back to the default behavior").
  CONVENTIONS.md's union rule only names `boolean | string-constant`
  (→ polymorphic variant); a nullable boolean isn't that shape, but
  `option` is the obvious translation and reads as an extension of the
  same idea rather than a new one.
- **Nothing was left unbound.** Every export of `@codemirror/lint` has an
  OCaml counterpart; unlike `Cm_view`'s `StateEffectType`/`AnnotationType`
  friction, `setDiagnosticsEffect` needed no `Obj.magic` or private-record
  workaround, because `Cm_state.StateEffectType.of_jv` (added to fix that
  exact problem in `Cm_view`) was already there to wrap a
  CodeMirror-constructed effect type directly.
