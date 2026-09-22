let pkg = lazy (Jv.get Jv.global "__CM__theme_one_dark")
let get name = Jv.get (Lazy.force pkg) name
let one_dark : Cm_state.Extension.t = Cm_state.Extension.of_jv (get "oneDark")

let one_dark_theme : Cm_state.Extension.t =
  Cm_state.Extension.of_jv (get "oneDarkTheme")

let one_dark_highlight_style : Cm_language.HighlightStyle.t =
  Cm_language.HighlightStyle.of_jv (get "oneDarkHighlightStyle")

module Color = struct
  let color = lazy (get "color")
  let s name = Jv.Jstr.get (Lazy.force color) name |> Jstr.to_string
  let chalky = s "chalky"
  let coral = s "coral"
  let cyan = s "cyan"
  let invalid = s "invalid"
  let ivory = s "ivory"
  let stone = s "stone"
  let malibu = s "malibu"
  let sage = s "sage"
  let whiskey = s "whiskey"
  let violet = s "violet"
  let dark_background = s "darkBackground"
  let highlight_background = s "highlightBackground"
  let background = s "background"
  let tooltip_background = s "tooltipBackground"
  let selection = s "selection"
  let cursor = s "cursor"
end
