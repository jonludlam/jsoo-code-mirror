(** {{:https://codemirror.net/docs/ref/#view} \@codemirror/view}: the editor's
    display: the view, decorations, gutters, panels, tooltips and the extensions
    that draw them. *)

open Cm_state

(* Forward declarations, equated inside the modules below. See
   Cm_state's cross-reference convention: a module needing a type
   declared later in this file uses the forward abstract type instead. *)
type editor_view
type view_update
type block_info

type command = editor_view -> bool
(** {{:https://codemirror.net/docs/ref/#view.Command} view.Command} *)

(* Used by [EditorView.mouse_selection_style], declared here (rather than
   inside [EditorView]) purely so the type has a name before its one use,
   the same ad hoc placement [Cm_state]'s [change_by_range_result] uses. *)
type mouse_selection_style = {
  get :
    Brr.Ev.Mouse.t Brr.Ev.t -> extend:bool -> multiple:bool -> EditorSelection.t;
  update : view_update -> bool;
}
(** {{:https://codemirror.net/docs/ref/#view.MouseSelectionStyle}
     view.MouseSelectionStyle}. [update]'s JavaScript [boolean | void] result is
    collapsed to [bool] ([void] is [false]). *)

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
  val viewport_changed : t -> bool
  val viewport_moved : t -> bool
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
    ?eq:(t -> bool) ->
    ?update_dom:(Brr.El.t -> editor_view -> bool) ->
    ?estimated_height:int ->
    ?line_breaks:int ->
    ?ignore_event:(Brr.Ev.void Brr.Ev.t -> bool) ->
    ?coords_at:(Brr.El.t -> int -> int -> Jv.t option) ->
    ?destroy:(Brr.El.t -> unit) ->
    to_dom:(editor_view -> Brr.El.t) ->
    unit ->
    t
  (** Subclassing [WidgetType]: [to_dom] is required, the rest override the
      defaults. *)
end

(** {{:https://codemirror.net/docs/ref/#view.Direction} view.Direction} *)
module Direction : sig
  type t = Ltr | Rtl
end

(** {{:https://codemirror.net/docs/ref/#view.BidiSpan} view.BidiSpan}. A
    read-only value CodeMirror hands out; there is no constructor. *)
module BidiSpan : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val from : t -> int
  val to_ : t -> int
  val level : t -> int
  val dir : t -> Direction.t
end

(** {{:https://codemirror.net/docs/ref/#view.Rect} view.Rect}: a plain
    rectangle, not a class of its own. *)
module Rect : sig
  type t = { left : float; right : float; top : float; bottom : float }

  val of_jv : Jv.t -> t
end

(** {{:https://codemirror.net/docs/ref/#view.Decoration} view.Decoration} *)
module Decoration : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  type attrs = (string * string) list

  val mark :
    ?inclusive:bool ->
    ?inclusive_start:bool ->
    ?inclusive_end:bool ->
    ?attributes:attrs ->
    ?class_:string ->
    ?tag_name:string ->
    ?bidi_isolate:Direction.t ->
    unit ->
    t

  val widget :
    ?side:int ->
    ?inclusive:bool ->
    ?inclusive_start:bool ->
    ?inclusive_end:bool ->
    ?block:bool ->
    WidgetType.t ->
    t

  val replace :
    ?widget:WidgetType.t ->
    ?inclusive:bool ->
    ?inclusive_start:bool ->
    ?inclusive_end:bool ->
    ?block:bool ->
    unit ->
    t

  val line : ?attributes:attrs -> ?class_:string -> unit -> t

  val range : ?to_:int -> t -> from:int -> t Range.t
  (** [to_] defaults to [from]: a point rather than a span. *)

  val none : t RangeSet.t
  val set : ?sort:bool -> t Range.t list -> t RangeSet.t
  val spec : t -> Jv.t
end

(** {{:https://codemirror.net/docs/ref/#view.EditorViewConfig}
     view.EditorViewConfig} *)
module EditorViewConfig : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?state:EditorState.t ->
    ?doc:string ->
    ?selection:EditorSelection.t ->
    ?extensions:Extension.t ->
    ?parent:Brr.El.t ->
    ?root:Brr.Document.t ->
    ?scroll_to:StateEffect.t ->
    ?dispatch_transactions:(Transaction.t list -> editor_view -> unit) ->
    unit ->
    t
  (** [doc], [selection] and [extensions] are the shortcut CodeMirror offers for
      creating the state along with the view. *)
end

(** {{:https://codemirror.net/docs/ref/#view.ViewPlugin} view.ViewPlugin}.
    Declared before {!EditorView}, whose [plugin] accessor mentions it. *)
module ViewPlugin : sig
  type 'a t

  (** Unlike {!Cm_state.StateField.define}, whose [update] returns the new
      value, a plugin's [update] returns [unit] and is expected to change the
      plugin's value in place, as CodeMirror's own [PluginValue] does. A plugin
      that keeps anything therefore wants a mutable record or a ref as its value
      type. *)
  val define :
    ?update:('a -> view_update -> unit) ->
    ?doc_view_update:('a -> editor_view -> unit) ->
    ?destroy:('a -> unit) ->
    ?decorations:('a -> Decoration.t RangeSet.t) ->
    ?event_handlers:
      (string * ('a -> Brr.Ev.void Brr.Ev.t -> editor_view -> bool)) list ->
    ?provide:('a t -> Extension.t) ->
    (editor_view -> 'a) ->
    'a t
  (** The OCaml value returned by the constructor is the plugin value; its
      methods are the optional arguments. *)

  val extension : 'a t -> Extension.t
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

  val set_doc : t -> string -> unit
  (** Not in CodeMirror: [set_doc view doc] dispatches one transaction replacing
      the whole document with [doc]. *)

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
  (** Read from the editor's measured layout, not from the extension, so it does
      not see a {!line_wrapping_extension} installed earlier in the same tick:
      it updates on the next measurement pass. To check the effect of a
      reconfiguration immediately, look for the [cm-lineWrapping] class on the
      content element instead. *)

  val text_direction : t -> Direction.t
  val viewport : t -> int * int
  val visible_ranges : t -> (int * int) list
  val pos_at_coords : ?precise:bool -> t -> x:float -> y:float -> int option

  val coords_at_pos : ?side:int -> t -> int -> Jv.t option
  (** a {!Rect}; the raw JavaScript value, as fixed by the design (see
      DESIGN.md's friction notes). *)

  val default_line_height : t -> float
  val default_character_width : t -> float
  val plugin : t -> 'a ViewPlugin.t -> 'a option

  (* Not part of the fixed signature; the rest of EditorView's instance
     surface, bound the same way. *)
  val composition_started : t -> bool
  val theme_classes : t -> string
  val document_top : t -> float
  val document_padding : t -> float * float
  val scale_x : t -> float
  val scale_y : t -> float
  val element_at_height : t -> float -> block_info
  val line_block_at_height : t -> float -> block_info
  val viewport_line_blocks : t -> block_info list
  val line_block_at : t -> int -> block_info
  val content_height : t -> float

  val move_by_char :
    t ->
    SelectionRange.t ->
    bool ->
    ?by:(string -> string -> bool) ->
    unit ->
    SelectionRange.t

  val move_by_group : t -> SelectionRange.t -> bool -> SelectionRange.t
  val visual_line_side : t -> Line.t -> bool -> SelectionRange.t

  val move_to_line_boundary :
    t ->
    SelectionRange.t ->
    bool ->
    ?include_wrap:bool ->
    unit ->
    SelectionRange.t

  val move_vertically :
    t -> SelectionRange.t -> bool -> ?distance:float -> unit -> SelectionRange.t

  val dom_at_pos : t -> int -> Brr.El.t * int
  val pos_at_dom : t -> ?offset:int -> Brr.El.t -> int
  val coords_for_char : t -> int -> Rect.t option
  val text_direction_at : t -> int -> Direction.t
  val bidi_spans : t -> Line.t -> BidiSpan.t list
  val set_root : t -> Brr.Document.t -> unit
  val scroll_snapshot : t -> StateEffect.t
  val set_tab_focus_mode : ?to_:[ `Bool of bool | `Ms of int ] -> t -> unit

  (* statics: fixed part *)
  val theme : ?dark:bool -> StyleSpec.t -> Extension.t
  val base_theme : StyleSpec.t -> Extension.t
  val line_wrapping_extension : Extension.t
  val editable : (bool, bool) Facet.t
  val dark_theme : (bool, bool) Facet.t
  val decorations : (Decoration.t RangeSet.t, Jv.t) Facet.t
  val outer_decorations : (Decoration.t RangeSet.t, Jv.t) Facet.t
  val atomic_ranges : (editor_view -> Decoration.t RangeSet.t, Jv.t) Facet.t
  val update_listener : (view_update -> unit, Jv.t) Facet.t

  val dom_event_handlers :
    (string * (Brr.Ev.void Brr.Ev.t -> editor_view -> bool)) list -> Extension.t

  val input_handler :
    (editor_view -> from:int -> to_:int -> string -> bool, Jv.t) Facet.t

  val content_attributes : ((string * string) list, Jv.t) Facet.t
  val editor_attributes : ((string * string) list, Jv.t) Facet.t
  val scroll_margins : (editor_view -> Jv.t option, Jv.t) Facet.t
  val exception_sink : (Jv.t -> unit, Jv.t) Facet.t
  val announce : string StateEffectType.t

  val scroll_into_view :
    ?y:string ->
    ?x:string ->
    ?y_margin:int ->
    ?x_margin:int ->
    int ->
    StateEffect.t

  val find_from_dom : Brr.El.t -> t option

  (* statics: the rest of the exported surface *)
  val dom_event_observers :
    (string * (Brr.Ev.void Brr.Ev.t -> editor_view -> unit)) list -> Extension.t

  val clipboard_input_filter : (string -> EditorState.t -> string, Jv.t) Facet.t

  val clipboard_output_filter :
    (string -> EditorState.t -> string, Jv.t) Facet.t

  val scroll_handler :
    ( editor_view ->
      SelectionRange.t ->
      x:string ->
      y:string ->
      x_margin:int ->
      y_margin:int ->
      bool,
      Jv.t )
    Facet.t

  val focus_change_effect :
    (EditorState.t -> focusing:bool -> StateEffect.t option, Jv.t) Facet.t

  val per_line_text_direction : (bool, bool) Facet.t

  val mouse_selection_style :
    ( editor_view -> Brr.Ev.Mouse.t Brr.Ev.t -> mouse_selection_style option,
      Jv.t )
    Facet.t

  val drag_moves_selection : (Brr.Ev.Mouse.t Brr.Ev.t -> bool, Jv.t) Facet.t

  val click_adds_selection_range :
    (Brr.Ev.Mouse.t Brr.Ev.t -> bool, Jv.t) Facet.t

  val bidi_isolated_ranges : (Decoration.t RangeSet.t, Jv.t) Facet.t
  val csp_nonce : (string, string) Facet.t
end

(** {{:https://codemirror.net/docs/ref/#view.KeyBinding} view.KeyBinding} *)
module KeyBinding : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?key:string ->
    ?mac:string ->
    ?win:string ->
    ?linux:string ->
    ?run:command ->
    ?shift:command ->
    ?any:(editor_view -> Brr.Ev.Keyboard.t Brr.Ev.t -> bool) ->
    ?scope:string ->
    ?prevent_default:bool ->
    ?stop_propagation:bool ->
    unit ->
    t
end

val keymap : (KeyBinding.t list, Jv.t) Facet.t
(** {{:https://codemirror.net/docs/ref/#view.keymap} view.keymap} *)

val run_scope_handlers :
  editor_view -> Brr.Ev.Keyboard.t Brr.Ev.t -> string -> bool
(** {{:https://codemirror.net/docs/ref/#view.runScopeHandlers}
     view.runScopeHandlers} *)

(** {{:https://codemirror.net/docs/ref/#view.GutterMarker} view.GutterMarker} *)
module GutterMarker : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val make :
    ?eq:(t -> bool) ->
    ?element_class:string ->
    ?destroy:(Brr.El.t -> unit) ->
    to_dom:(editor_view -> Brr.El.t) ->
    unit ->
    t

  val range : ?to_:int -> t -> from:int -> t Range.t
  (** [to_] defaults to [from]: a point rather than a span. *)
end

(** {{:https://codemirror.net/docs/ref/#view.BlockType} view.BlockType} *)
module BlockType : sig
  type t = Text | Widget_before | Widget_after | Widget_range
end

(** {{:https://codemirror.net/docs/ref/#view.BlockInfo} view.BlockInfo} *)
module BlockInfo : sig
  type t = block_info

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val from : t -> int
  val to_ : t -> int
  val length : t -> int
  val top : t -> float
  val bottom : t -> float
  val height : t -> float
  val type_ : t -> [ `Type of BlockType.t | `Blocks of t list ]
  val widget : t -> WidgetType.t option
  val widget_line_breaks : t -> int
end

val gutter :
  ?class_:string ->
  ?markers:(editor_view -> GutterMarker.t RangeSet.t) ->
  ?line_marker:
    (editor_view -> BlockInfo.t -> GutterMarker.t list -> GutterMarker.t option) ->
  ?widget_marker:
    (editor_view -> WidgetType.t -> BlockInfo.t -> GutterMarker.t option) ->
  ?line_marker_change:(view_update -> bool) ->
  ?initial_spacer:(editor_view -> GutterMarker.t) ->
  ?update_spacer:(GutterMarker.t -> view_update -> GutterMarker.t) ->
  ?dom_event_handlers:
    (string * (editor_view -> BlockInfo.t -> Brr.Ev.void Brr.Ev.t -> bool)) list ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#view.gutter} view.gutter} *)

val gutters : ?fixed:bool -> unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.gutters} view.gutters} *)

val line_numbers :
  ?format_number:(int -> EditorState.t -> string) ->
  ?dom_event_handlers:
    (string * (editor_view -> BlockInfo.t -> Brr.Ev.void Brr.Ev.t -> bool)) list ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#view.lineNumbers} view.lineNumbers} *)

val line_number_markers : (GutterMarker.t RangeSet.t, Jv.t) Facet.t
(** {{:https://codemirror.net/docs/ref/#view.lineNumberMarkers}
     view.lineNumberMarkers} *)

val gutter_line_class : (GutterMarker.t RangeSet.t, Jv.t) Facet.t
(** {{:https://codemirror.net/docs/ref/#view.gutterLineClass}
     view.gutterLineClass} *)

val gutter_widget_class :
  ( editor_view -> WidgetType.t -> BlockInfo.t -> GutterMarker.t option,
    Jv.t )
  Facet.t
(** {{:https://codemirror.net/docs/ref/#view.gutterWidgetClass}
     view.gutterWidgetClass} *)

val line_number_widget_marker :
  ( editor_view -> WidgetType.t -> BlockInfo.t -> GutterMarker.t option,
    Jv.t )
  Facet.t
(** {{:https://codemirror.net/docs/ref/#view.lineNumberWidgetMarker}
     view.lineNumberWidgetMarker} *)

val highlight_active_line_gutter : unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.highlightActiveLineGutter}
     view.highlightActiveLineGutter} *)

(** {{:https://codemirror.net/docs/ref/#view.Panel} view.Panel} *)
module Panel : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?mount:(unit -> unit) ->
    ?update:(view_update -> unit) ->
    ?destroy:(unit -> unit) ->
    ?top:bool ->
    Brr.El.t ->
    t

  val dom : t -> Brr.El.t
end

val show_panel : ((editor_view -> Panel.t) option, Jv.t) Facet.t
(** {{:https://codemirror.net/docs/ref/#view.showPanel} view.showPanel} *)

val panels :
  ?top_container:Brr.El.t -> ?bottom_container:Brr.El.t -> unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.panels} view.panels} *)

val get_panel : editor_view -> (editor_view -> Panel.t) -> Panel.t option
(** {{:https://codemirror.net/docs/ref/#view.getPanel} view.getPanel} *)

(** {{:https://codemirror.net/docs/ref/#view.Tooltip} view.Tooltip} and
    TooltipView *)
module TooltipView : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?offset:int * int ->
    ?overlap:bool ->
    ?mount:(editor_view -> unit) ->
    ?update:(view_update -> unit) ->
    ?destroy:(unit -> unit) ->
    ?positioned:(Jv.t -> unit) ->
    ?resize:bool ->
    Brr.El.t ->
    t

  val dom : t -> Brr.El.t
end

module Tooltip : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?end_:int ->
    ?above:bool ->
    ?strict_side:bool ->
    ?arrow:bool ->
    ?clip:bool ->
    pos:int ->
    create:(editor_view -> TooltipView.t) ->
    unit ->
    t

  val pos : t -> int
  val end_ : t -> int option
end

val show_tooltip : (Tooltip.t option, Jv.t) Facet.t
(** {{:https://codemirror.net/docs/ref/#view.showTooltip} view.showTooltip} *)

val hover_tooltip :
  ?hide_on_change:bool ->
  ?hover_time:int ->
  (editor_view -> pos:int -> side:int -> Tooltip.t option Fut.t) ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#view.hoverTooltip} view.hoverTooltip}.
    The source may return the tooltip synchronously; wrap it with [Fut.return].
    Drops the [active] state field JavaScript attaches to the returned
    extension, and the [hideOn] option. *)

val tooltips :
  ?position:string ->
  ?parent:Brr.El.t ->
  ?tooltip_space:(editor_view -> Jv.t) ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#view.tooltips} view.tooltips} *)

val get_tooltip : editor_view -> Tooltip.t -> TooltipView.t option
(** {{:https://codemirror.net/docs/ref/#view.getTooltip} view.getTooltip} *)

val has_hover_tooltips : EditorState.t -> bool
(** {{:https://codemirror.net/docs/ref/#view.hasHoverTooltips}
     view.hasHoverTooltips} *)

val close_hover_tooltips : StateEffect.t
(** {{:https://codemirror.net/docs/ref/#view.closeHoverTooltips}
     view.closeHoverTooltips} *)

val reposition_tooltips : editor_view -> unit
(** {{:https://codemirror.net/docs/ref/#view.repositionTooltips}
     view.repositionTooltips} *)

val draw_selection :
  ?cursor_blink_rate:int -> ?draw_range_cursor:bool -> unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.drawSelection} view.drawSelection}
*)

type selection_config = { cursor_blink_rate : int; draw_range_cursor : bool }

val get_draw_selection_config : EditorState.t -> selection_config
(** {{:https://codemirror.net/docs/ref/#view.getDrawSelectionConfig}
     view.getDrawSelectionConfig} *)

val drop_cursor : unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.dropCursor} view.dropCursor} *)

val highlight_active_line : unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.highlightActiveLine}
     view.highlightActiveLine} *)

val highlight_special_chars :
  ?render:(int -> string option -> string -> Brr.El.t) ->
  ?special_chars:Jv.t ->
  ?add_special_chars:Jv.t ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#view.highlightSpecialChars}
     view.highlightSpecialChars}. [special_chars]/[add_special_chars] are
    JavaScript [RegExp] values, passed through as [Jv.t]. *)

val highlight_whitespace : unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.highlightWhitespace}
     view.highlightWhitespace} *)

val highlight_trailing_whitespace : unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.highlightTrailingWhitespace}
     view.highlightTrailingWhitespace} *)

val placeholder : [ `Text of string | `El of Brr.El.t ] -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.placeholder} view.placeholder}.
    Drops the function-of-view form of the content argument. *)

val rectangular_selection :
  ?event_filter:(Brr.Ev.Mouse.t Brr.Ev.t -> bool) -> unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.rectangularSelection}
     view.rectangularSelection} *)

val crosshair_cursor : ?key:string -> unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.crosshairCursor}
     view.crosshairCursor} *)

val scroll_past_end : unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#view.scrollPastEnd} view.scrollPastEnd}
*)

val log_exception : EditorState.t -> Jv.t -> unit
(** {{:https://codemirror.net/docs/ref/#view.logException} view.logException} *)

(** {{:https://codemirror.net/docs/ref/#view.LayerMarker} view.LayerMarker}. A
    plain duck-typed interface; [create] builds a value satisfying it. *)
module LayerMarker : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?update:(Brr.El.t -> t -> bool) ->
    eq:(t -> bool) ->
    draw:(unit -> Brr.El.t) ->
    unit ->
    t
end

val layer :
  ?class_:string ->
  ?update_on_doc_view_update:bool ->
  ?mount:(Brr.El.t -> editor_view -> unit) ->
  ?destroy:(Brr.El.t -> editor_view -> unit) ->
  above:bool ->
  update:(view_update -> Brr.El.t -> bool) ->
  markers:(editor_view -> LayerMarker.t list) ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#view.layer} view.layer} *)

(** {{:https://codemirror.net/docs/ref/#view.RectangleMarker}
     view.RectangleMarker}. Structurally satisfies {!LayerMarker}, but is bound
    as its own type; convert through {!LayerMarker.to_jv}/[of_jv] to mix the
    two. *)
module RectangleMarker : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val make :
    class_:string ->
    left:float ->
    top:float ->
    width:float option ->
    height:float ->
    t

  val for_range : editor_view -> class_:string -> SelectionRange.t -> t list
end

(** Not bound:

    - [EditorView.root]: a [Document | ShadowRoot] getter. Only [Document] is
      bound elsewhere in this package (see [EditorViewConfig.create]'s [root]);
      exposing the getter would need a sum type wrapping both DOM types this
      binding otherwise avoids.
    - [EditorView.styleModule]: a facet over [StyleModule] from the [style-mod]
      package, which this binding does not otherwise depend on or expose.
    - [EditorView.requestMeasure]'s [MeasureRequest<T>] argument: a generic
      read/write/key protocol keyed by an opaque [T]; the fixed signature
      already reduces [request_measure] to the argument-less trigger, so the
      read/write pair is dropped along with it.
    - [PluginSpec.eventObservers]: [ViewPlugin.define]'s signature is fixed by
      DESIGN.md and does not have room for a second handler map alongside
      [event_handlers].
    - [ScrollTarget]: its [map]/[clip] methods need the [T] payload of the
      [StateEffect<ScrollTarget>] that [EditorView.scrollSnapshot] returns, but
      this binding's [StateEffect.t] is monomorphic (see [Cm_state]'s
      forward-type convention), so the effect is exposed only as an opaque
      [StateEffect.t] with no way to read the [ScrollTarget] back out.
    - [MatchDecorator]: its configuration is keyed by a JavaScript [RegExp],
      which this binding does not otherwise construct or expose; binding it well
      would mean adding a general [RegExp] wrapper outside this package's scope.
    - [AttrSource]'s function-of-view alternative for
      [EditorView.contentAttributes]/[editorAttributes]: the fixed signature
      only accepts the plain attribute-list form. *)
