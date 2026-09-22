(** {{:https://github.com/codemirror/legacy-modes} \@codemirror/legacy-modes}:
    stream parsers ported from CodeMirror 5, for languages with no Lezer
    grammar.

    Each value here is the mode object; turn one into a language with
    {!Cm_language.StreamLanguage.define}:

    {[
      let ocaml = Cm_language.StreamLanguage.define Cm_legacy_modes.ocaml
    ]}

    Only the modes listed here are in this library's bundle. To add one,
    import it in [js/entries/legacy_modes.js] and add a value below. *)

val ocaml : Cm_language.StreamParser.t
(** From the [mllike] mode. *)

val fsharp : Cm_language.StreamParser.t
val sml : Cm_language.StreamParser.t
