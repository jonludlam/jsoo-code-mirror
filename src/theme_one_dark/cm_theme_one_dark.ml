let pkg = Jv.get Jv.global "__CM__theme_one_dark"

let one_dark : Cm_state.Extension.t =
  Cm_state.Extension.of_jv (Jv.get pkg "oneDark")
