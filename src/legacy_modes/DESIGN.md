# Cm_legacy_modes

The bundle exposes `__CM__legacy_modes = { mllike }` from
`@codemirror/legacy-modes/mode/mllike`. Bind each mode object as a
`Cm_language.StreamParser.t` value: `val ocaml : StreamParser.t`,
`val fsharp : StreamParser.t`, `val sml : StreamParser.t` (the mllike
module exports oCaml, fSharp, sml). A user does
`Cm_language.StreamLanguage.define Cm_legacy_modes.ocaml` to get a
language. To add a mode, add an import line to js/entries/legacy_modes.js
and a value here.
