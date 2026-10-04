(* The `codemirror` package: every package, plus basicSetup. *)

module State = Cm_state
module View = Cm_view
module Language = Cm_language
module Autocomplete = Cm_autocomplete
module Lint = Cm_lint

let basic_setup : State.Extension.t =
  State.Extension.of_jv (Jv.get Jv.global "__CM__basic_setup")
