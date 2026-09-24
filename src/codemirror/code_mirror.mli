(** {{:https://codemirror.net/} CodeMirror 6}.

    This library re-exports every package's bindings and adds the
    [codemirror] package's two setup bundles. Depending on it links all of
    CodeMirror, as depending on the [codemirror] npm package does; for a
    smaller page, depend on the sub-libraries you use ([code-mirror.state],
    [code-mirror.view], and so on) and load only their bundles.

    Each module is documented in the library it comes from. *)

module State = Cm_state
module View = Cm_view
module Language = Cm_language
module Commands = Cm_commands
module Autocomplete = Cm_autocomplete
module Lint = Cm_lint
module Search = Cm_search
module Collab = Cm_collab
module Lsp_client = Cm_lsp_client
module Legacy_modes = Cm_legacy_modes
module Theme_one_dark = Cm_theme_one_dark

val basic_setup : State.Extension.t
(** {{:https://codemirror.net/docs/ref/#codemirror.basicSetup} basicSetup}:
    the line numbers, history, highlighting, autocompletion, search and
    key bindings most editors want. *)

val minimal_setup : State.Extension.t
(** {{:https://codemirror.net/docs/ref/#codemirror.minimalSetup} minimalSetup}:
    history, syntax highlighting and the default key bindings, and no more. *)
