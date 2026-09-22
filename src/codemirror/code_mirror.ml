(* The `codemirror` package: everything, plus basicSetup and minimalSetup. *)
let pkg = lazy (Jv.get Jv.global "__CM__codemirror")

module State = Cm_state
module View = Cm_view
module Language = Cm_language
module Commands = Cm_commands
module Autocomplete = Cm_autocomplete
module Lint = Cm_lint
module Search = Cm_search
module Legacy_modes = Cm_legacy_modes
module Theme_one_dark = Cm_theme_one_dark

let basic_setup () = Jv.get (Lazy.force pkg) "basicSetup"
let minimal_setup () = Jv.get (Lazy.force pkg) "minimalSetup"
