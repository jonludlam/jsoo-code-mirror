(** {{:https://github.com/codemirror/theme-one-dark} \@codemirror/theme-one-dark}:
    the One Dark theme, as an editor theme and a matching highlight style.

    Not part of CodeMirror's reference, since it is a theme package rather
    than part of the editor. *)

val one_dark : Cm_state.Extension.t
(** The theme and its highlight style together: what most pages want. *)

val one_dark_theme : Cm_state.Extension.t
(** The editor colours alone, without the syntax highlighting. *)

val one_dark_highlight_style : Cm_language.HighlightStyle.t
(** The syntax colours alone. Install with
    {!Cm_language.syntax_highlighting}. *)

(** The palette the theme is built from, should a page want to match it. *)
module Color : sig
  val chalky : string
  val coral : string
  val cyan : string
  val invalid : string
  val ivory : string
  val stone : string
  val malibu : string
  val sage : string
  val whiskey : string
  val violet : string
  val dark_background : string
  val highlight_background : string
  val background : string
  val tooltip_background : string
  val selection : string
  val cursor : string
end
