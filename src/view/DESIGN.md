# Cm_view: the shape of the design-critical modules

Fixed signatures; implement exactly, then bind the rest of
`@codemirror/view` (node_modules/@codemirror/view/dist/index.d.ts) in the
same style. One `cm_view.ml` / `cm_view.mli` pair. `Cm_state` is a
dependency: use its `Conv`, `Extension`, `Facet`, `StateEffectType`,
`RangeSet`, `Transaction`, `TransactionSpec`, `EditorState` directly
(`open Cm_state` at the top of both files is fine).

Naming rule for clashes: a class's instance getter keeps the name; a
static facet or extension of the same name takes a suffix: `_facet` for a
facet, `_extension` for an extension (`EditorView.line_wrapping : t ->
bool` and `EditorView.line_wrapping_extension : Extension.t`).

```ocaml
(** {{:https://codemirror.net/docs/ref/#view} @codemirror/view}: the
    editor's display: the view, decorations, gutters, panels, tooltips and
    the extensions that draw them. *)

open Cm_state

type editor_view
type view_update
type command = editor_view -> bool
(** {{:https://codemirror.net/docs/ref/#view.Command} view.Command} *)

(** A CSS-in-JS style sheet, CodeMirror's [StyleSpec]. *)
module StyleSpec : sig
  type t = (string * value) list
  and value = Value of string | Rules of t
  val to_jv : t -> Jv.t
end

(** {{:https://codemirror.net/docs/ref/#view.ViewUpdate} view.ViewUpdate} *)
module ViewUpdate : sig
  type t = view_update
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val view : t -> editor_view
  val state : t -> EditorState.t
  val start_state : t -> EditorState.t
  val changes : t -> ChangeSet.t
  val transactions : t -> Transaction.t list
  val view_changed : t -> bool
  val height_changed : t -> bool
  val geometry_changed : t -> bool
  val focus_changed : t -> bool
  val doc_changed : t -> bool
  val selection_set : t -> bool
end

(** {{:https://codemirror.net/docs/ref/#view.WidgetType} view.WidgetType} *)
module WidgetType : sig
  type t
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val make :
    ?eq:(t -> bool) -> ?update_dom:(Brr.El.t -> editor_view -> bool) ->
    ?estimated_height:int -> ?line_breaks:int -> ?ignore_event:(Brr.Ev.void Brr.Ev.t -> bool) ->
    ?coords_at:(Brr.El.t -> int -> int -> Jv.t option) -> ?destroy:(Brr.El.t -> unit) ->
    to_dom:(editor_view -> Brr.El.t) -> unit -> t
  (** Subclassing [WidgetType]: [to_dom] is required, the rest override the defaults. *)
end

(** {{:https://codemirror.net/docs/ref/#view.Decoration} view.Decoration} *)
module Decoration : sig
  type t
  include Jv.CONV with type t := t
  val conv : t Conv.t
  type attrs = (string * string) list
  val mark : ?inclusive:bool -> ?inclusive_start:bool -> ?inclusive_end:bool -> ?attributes:attrs -> ?class_:string -> ?tag_name:string -> ?bidi_isolate:Direction.t -> unit -> t
  val widget : ?side:int -> ?inclusive:bool -> ?inclusive_start:bool -> ?inclusive_end:bool -> ?block:bool -> WidgetType.t -> t
  val replace : ?widget:WidgetType.t -> ?inclusive:bool -> ?inclusive_start:bool -> ?inclusive_end:bool -> ?block:bool -> unit -> t
  val line : ?attributes:attrs -> ?class_:string -> unit -> t
  val range : ?to_:int -> t -> from:int -> t Range.t
  val none : t RangeSet.t
  val set : ?sort:bool -> t Range.t list -> t RangeSet.t
  val spec : t -> Jv.t
end
(* Direction is an enum declared before Decoration: *)
module Direction : sig type t = Ltr | Rtl end

(** {{:https://codemirror.net/docs/ref/#view.EditorViewConfig} view.EditorViewConfig} *)
module EditorViewConfig : sig
  type t
  include Jv.CONV with type t := t
  val create :
    ?state:EditorState.t -> ?doc:string -> ?selection:EditorSelection.t -> ?extensions:Extension.t ->
    ?parent:Brr.El.t -> ?root:Brr.Document.t -> ?scroll_to:StateEffect.t ->
    ?dispatch_transactions:(Transaction.t list -> editor_view -> unit) -> unit -> t
  (** [doc], [selection] and [extensions] are the shortcut CodeMirror
      offers for creating the state along with the view. *)
end

(** {{:https://codemirror.net/docs/ref/#view.EditorView} view.EditorView} *)
module EditorView : sig
  type t = editor_view
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val create : ?config:EditorViewConfig.t -> unit -> t
  val state : t -> EditorState.t
  val set_state : t -> EditorState.t -> unit
  val dispatch : t -> TransactionSpec.t -> unit
  val dispatch_all : t -> TransactionSpec.t list -> unit
  val dispatch_transaction : t -> Transaction.t -> unit
  val update : t -> Transaction.t list -> unit
  val dom : t -> Brr.El.t
  val content_dom : t -> Brr.El.t
  val scroll_dom : t -> Brr.El.t
  val focus : t -> unit
  val has_focus : t -> bool
  val destroy : t -> unit
  val request_measure : t -> unit
  val composing : t -> bool
  val in_view : t -> bool
  val line_wrapping : t -> bool
  val text_direction : t -> Direction.t
  val viewport : t -> int * int
  val visible_ranges : t -> (int * int) list
  val pos_at_coords : ?precise:bool -> t -> x:float -> y:float -> int option
  val coords_at_pos : ?side:int -> t -> int -> Jv.t option   (* a Rect; bind Rect as a record {left; right; top; bottom} *)
  val default_line_height : t -> float
  val default_character_width : t -> float
  val plugin : t -> 'a ViewPlugin.t -> 'a option   (* ViewPlugin declared before EditorView *)
  (* statics *)
  val theme : ?dark:bool -> StyleSpec.t -> Extension.t
  val base_theme : StyleSpec.t -> Extension.t
  val line_wrapping_extension : Extension.t
  val editable : (bool, bool) Facet.t
  val dark_theme : (bool, bool) Facet.t
  val decorations : (Decoration.t RangeSet.t, Jv.t) Facet.t
  val outer_decorations : (Decoration.t RangeSet.t, Jv.t) Facet.t
  val atomic_ranges : ((editor_view -> Decoration.t RangeSet.t), Jv.t) Facet.t
  val update_listener : ((view_update -> unit), Jv.t) Facet.t
  val dom_event_handlers : (string * (Brr.Ev.void Brr.Ev.t -> editor_view -> bool)) list -> Extension.t
  val input_handler : ((editor_view -> from:int -> to_:int -> string -> bool), Jv.t) Facet.t
  val content_attributes : ((string * string) list, Jv.t) Facet.t
  val editor_attributes : ((string * string) list, Jv.t) Facet.t
  val scroll_margins : ((editor_view -> Jv.t option), Jv.t) Facet.t
  val exception_sink : ((Jv.t -> unit), Jv.t) Facet.t
  val announce : string StateEffectType.t
  val scroll_into_view : ?y:string -> ?x:string -> ?y_margin:int -> ?x_margin:int -> int -> StateEffect.t
  val find_from_dom : Brr.El.t -> t option
end

(** {{:https://codemirror.net/docs/ref/#view.ViewPlugin} view.ViewPlugin} *)
module ViewPlugin : sig
  type 'a t
  val define :
    ?update:('a -> view_update -> unit) -> ?doc_view_update:('a -> editor_view -> unit) -> ?destroy:('a -> unit) ->
    ?decorations:('a -> Decoration.t RangeSet.t) -> ?event_handlers:(string * ('a -> Brr.Ev.void Brr.Ev.t -> editor_view -> bool)) list ->
    ?provide:('a t -> Extension.t) -> (editor_view -> 'a) -> 'a t
  (** The OCaml value returned by the constructor is the plugin value; its
      methods are the optional arguments. *)
  val extension : 'a t -> Extension.t
end

(** {{:https://codemirror.net/docs/ref/#view.KeyBinding} view.KeyBinding} *)
module KeyBinding : sig
  type t
  include Jv.CONV with type t := t
  val create : ?key:string -> ?mac:string -> ?win:string -> ?linux:string -> ?run:command -> ?shift:command -> ?any:(editor_view -> Brr.Ev.Keyboard.t Brr.Ev.t -> bool) -> ?scope:string -> ?prevent_default:bool -> ?stop_propagation:bool -> unit -> t
end
val keymap : (KeyBinding.t list, Jv.t) Facet.t
(** {{:https://codemirror.net/docs/ref/#view.keymap} view.keymap} *)
val run_scope_handlers : editor_view -> Brr.Ev.Keyboard.t Brr.Ev.t -> string -> bool

(** {{:https://codemirror.net/docs/ref/#view.GutterMarker} view.GutterMarker} *)
module GutterMarker : sig
  type t
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val make : ?eq:(t -> bool) -> ?element_class:string -> ?destroy:(Brr.El.t -> unit) -> to_dom:(editor_view -> Brr.El.t) -> unit -> t
  val range : ?to_:int -> t -> from:int -> t Range.t
end
val gutter : ?class_:string -> ?markers:(editor_view -> GutterMarker.t RangeSet.t) -> ?line_marker:(editor_view -> BlockInfo.t -> GutterMarker.t list -> GutterMarker.t option) -> ?widget_marker:(editor_view -> WidgetType.t -> BlockInfo.t -> GutterMarker.t option) -> ?line_marker_change:(view_update -> bool) -> ?initial_spacer:(editor_view -> GutterMarker.t) -> ?update_spacer:(GutterMarker.t -> view_update -> GutterMarker.t) -> ?dom_event_handlers:(string * (editor_view -> BlockInfo.t -> Brr.Ev.void Brr.Ev.t -> bool)) list -> unit -> Extension.t
val gutters : ?fixed:bool -> unit -> Extension.t
val line_numbers : ?format_number:(int -> EditorState.t -> string) -> ?dom_event_handlers:(string * (editor_view -> BlockInfo.t -> Brr.Ev.void Brr.Ev.t -> bool)) list -> unit -> Extension.t
val line_number_markers : (GutterMarker.t RangeSet.t, Jv.t) Facet.t
val highlight_active_line_gutter : unit -> Extension.t
(* BlockInfo (from, to_, length, top, bottom, height, type) is a record-reading module declared before gutter. *)

(** {{:https://codemirror.net/docs/ref/#view.Panel} view.Panel} *)
module Panel : sig
  type t
  include Jv.CONV with type t := t
  val create : ?mount:(unit -> unit) -> ?update:(view_update -> unit) -> ?destroy:(unit -> unit) -> ?top:bool -> Brr.El.t -> t
  val dom : t -> Brr.El.t
end
val show_panel : ((editor_view -> Panel.t) option, Jv.t) Facet.t
val panels : ?top_container:Brr.El.t -> ?bottom_container:Brr.El.t -> unit -> Extension.t
val get_panel : editor_view -> (editor_view -> Panel.t) -> Panel.t option

(** {{:https://codemirror.net/docs/ref/#view.Tooltip} view.Tooltip} and TooltipView *)
module TooltipView : sig
  type t
  include Jv.CONV with type t := t
  val create : ?offset:(int * int) -> ?overlap:bool -> ?mount:(editor_view -> unit) -> ?update:(view_update -> unit) -> ?destroy:(unit -> unit) -> ?positioned:(Jv.t -> unit) -> ?resize:bool -> Brr.El.t -> t
  val dom : t -> Brr.El.t
end
module Tooltip : sig
  type t
  include Jv.CONV with type t := t
  val create : ?end_:int -> ?above:bool -> ?strict_side:bool -> ?arrow:bool -> ?clip:bool -> pos:int -> create:(editor_view -> TooltipView.t) -> unit -> t
  val pos : t -> int
  val end_ : t -> int option
end
val show_tooltip : (Tooltip.t option, Jv.t) Facet.t
val hover_tooltip : ?hide_on_change:bool -> ?hover_time:int -> (editor_view -> pos:int -> side:int -> Tooltip.t option Fut.t) -> Extension.t
(** The source may return the tooltip synchronously; wrap it with [Fut.return]. *)
val tooltips : ?position:string -> ?parent:Brr.El.t -> ?tooltip_space:(editor_view -> Jv.t) -> unit -> Extension.t
val get_tooltip : editor_view -> Tooltip.t -> TooltipView.t option
val has_hover_tooltips : EditorState.t -> bool
val close_hover_tooltips : StateEffect.t
val reposition_tooltips : editor_view -> unit

(* Plain extension functions of the package, each `?args -> unit -> Extension.t`: *)
val draw_selection : ?cursor_blink_rate:int -> ?draw_range_cursor:bool -> unit -> Extension.t
val drop_cursor : unit -> Extension.t
val highlight_active_line : unit -> Extension.t
val highlight_special_chars : ?render:(int -> string option -> string -> Brr.El.t) -> ?special_chars:Jv.t -> ?add_special_chars:Jv.t -> unit -> Extension.t
val highlight_whitespace : unit -> Extension.t
val highlight_trailing_whitespace : unit -> Extension.t
val placeholder : [ `Text of string | `El of Brr.El.t ] -> Extension.t
val rectangular_selection : ?event_filter:(Brr.Ev.Mouse.t Brr.Ev.t -> bool) -> unit -> Extension.t
val crosshair_cursor : ?key:string -> unit -> Extension.t
val scroll_past_end : unit -> Extension.t
val log_exception : EditorState.t -> Jv.t -> unit
```

Bind `MatchDecorator`, `layer`/`RectangleMarker`, `BidiSpan` and
`ScrollTarget` only if straightforward; otherwise list them under "Not
bound" at the end of the .mli.
