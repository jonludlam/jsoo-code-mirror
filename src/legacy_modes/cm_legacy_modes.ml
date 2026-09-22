let pkg = lazy (Jv.get Jv.global "__CM__legacy_modes")
let mode group name = Jv.get (Jv.get (Lazy.force pkg) group) name

let ocaml : Cm_language.StreamParser.t =
  Cm_language.StreamParser.of_jv (mode "mllike" "oCaml")

let fsharp : Cm_language.StreamParser.t =
  Cm_language.StreamParser.of_jv (mode "mllike" "fSharp")

let sml : Cm_language.StreamParser.t =
  Cm_language.StreamParser.of_jv (mode "mllike" "sml")
