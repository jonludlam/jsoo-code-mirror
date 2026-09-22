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

## Questions and friction

Things that turned out awkward, surprising, or worth a second look while
implementing the full package on top of the fixed signatures and
`Cm_state`.

- **`Conv`-carrying generics worked well for `Decoration.t RangeSet.t`
  itself, but every facet whose *value* is a function needs its own
  hand-written `Conv.t`, and there are a lot of those in this package.**
  `Decoration.t RangeSet.t` slots straight into `Cm_state.RangeSet.conv_of
  Decoration.conv` with no friction — that part of the design travels
  well. What was unexpectedly heavy is `EditorView`'s facets: `decorations`,
  `atomic_ranges`, `update_listener`, `dom_event_handlers`,
  `input_handler`, `content_attributes`, `scroll_margins`,
  `exception_sink`, `clipboard_input_filter`, `scroll_handler`,
  `focus_change_effect`, `mouse_selection_style`, `drag_moves_selection`
  and more are all `(some function type, Jv.t) Facet.t`, and each needs
  a bespoke `Conv.t` record built by hand (wrap the OCaml function in
  `Jv.callback`, unwrap the arguments, convert the result back) because
  `Conv` only ships primitives, `option`, `list` and `of_module` — there
  is no combinator for "a function from these argument types to this
  result type". In `Cm_state` this pattern shows up once or twice
  (`change_filter`, `transaction_filter`); in `Cm_view` it is the
  majority of `EditorView`'s static surface. None of it is hard, but it
  is a lot of near-identical boilerplate that a `Conv.fn1`/`Conv.fn2`-style
  helper (or even just `Conv.callback : ('a -> Jv.t) -> (Jv.t -> 'b) ->
  ('a -> 'b) Conv.t` for the common "wrap one argument, wrap the result"
  shape) would have cut by more than half.
- **The `_facet`/`_extension` suffix rule handles the clash DESIGN.md
  calls out (`line_wrapping`/`line_wrapping_extension`) but the fuller
  API has more instance-getter/static-facet pairs than the fixed
  signature's one example, and the rule scales to them fine** —
  `dark_theme`, `editable` etc. only exist as facets in this package (no
  instance getter of the same name), so no clash arises. The one
  surprise is that the CodeMirror source has *not just* getter/facet
  clashes but getter/static-*value* clashes (`EditorView.lineWrapping`
  the getter vs. `EditorView.lineWrapping` the `Extension` constant),
  which the naming rule's own example already anticipates — so in
  practice the rule was sufficient, just narrower in scope than it first
  appears (it does not need to say anything about facet/facet or
  extension/extension clashes, because CodeMirror itself never has two
  same-named statics on one class).
- **`get_panel`'s `PanelConstructor` argument can only ever return `None`
  in practice, because of how function values convert.** CodeMirror's
  `getPanel(view, ctor)` finds the active panel by comparing `ctor`
  against the constructor function the `showPanel` facet currently holds,
  using JavaScript reference equality. But converting an OCaml
  `editor_view -> Panel.t` to `Jv.t` (whether through `Facet.from`'s
  `?get`, `Facet.of_`, or a direct call to `get_panel`) allocates a *new*
  `Jv.callback` wrapper every time it runs — there is no way, through
  this binding's types, to hold onto "the same" JavaScript function
  across two separate conversions of what is logically the same OCaml
  closure. So a constructor built to register a panel and a
  textually-identical constructor built later to look it up are never
  `==` in JavaScript, and `get_panel` returns `None` even when the panel
  is actually showing (confirmed in `test/view/view.ml`, which found this
  while writing the panel check: the panel renders in the DOM, but
  `get_panel` can't find it unless the caller manually threads through
  the exact same `Jv.t` closure — which the typed signature has no
  vocabulary for). This isn't fixable within `get_panel`'s fixed
  signature; it would need either a way to intern/memoize function
  conversions by physical equality, or a lower-level `PanelConstructor.t`
  handle type that stays opaque instead of being reconverted from a
  bare OCaml function each time.
- **The `caml_js_wrap_meth_callback` primitive is the only way to
  implement `ViewPlugin.define`'s `event_handlers`, and it isn't part of
  `Jv`'s public interface.** CodeMirror invokes a `ViewPlugin`'s
  `eventHandlers` (and `EditorView.domEventHandlers`, for the same
  reason — both go through the same internal `bindHandler`) as
  `handler.call(pluginValue, event, view)`, relying on `this` to recover
  which view's plugin instance is calling a handler function that is
  shared, as one JavaScript closure, across every view the `ViewPlugin`
  is used in. `Jv.callback` (`caml_js_wrap_callback_strict`) does not
  forward `this`, so an event handler written with it can never
  recover the calling instance. The fix
  (`src/view/cm_view.ml`, `wrap_meth_callback3`) is a raw `external ... =
  "caml_js_wrap_meth_callback"` reaching past `Jv` into a js_of_ocaml
  runtime primitive `Jv` doesn't expose — it works, but a binding that
  needs to reach outside `Jv.mli` to implement a fixed signature is a
  sign that `Jv` is missing a combinator (something like
  `Jv.callback_meth : arity:int -> (Jv.t -> _ -> _) -> Jv.t`, `this` as
  the first argument) that any "class subclassed in JavaScript, shared
  across instances" binding will eventually need.
- **`EditorView.coords_at_pos`'s fixed `Jv.t option` return and the
  `Rect` module this file adds for everything else that returns a
  rectangle are inconsistent, and a reader can't tell why.** The fixed
  signature keeps `coords_at_pos : ... -> Jv.t option` verbatim (with a
  comment that it's "a Rect; bind Rect as a record"), while this file's
  own extensions (`coords_for_char`) return `Rect.t option`. Both values
  come from the exact same JavaScript shape (`{left, right, top,
  bottom}`); the only reason `coords_at_pos` stays `Jv.t` is that its
  signature was fixed before `Rect` existed. It would read better either
  fixed as `Rect.t option` from the start, or with a one-line note next
  to it explaining the split is historical rather than meaningful.
- **The `Cm_state.Conv`-based facet/state-field style pushes real
  complexity into "convert a stateful JavaScript interface object", and
  `MouseSelectionStyle` is the sharpest example.** Unlike the
  callback-shaped facets above, `EditorView.mouseSelectionStyle`'s value
  is an object with *two* methods (`get`, `update`) that CodeMirror
  calls back into over the lifetime of one mouse gesture. Expressing
  that as a `Cm_view`-side record (`mouse_selection_style`) with its own
  hand-written `Conv.t` works, but it's a third shape (after "plain
  value" and "single-argument function") that this convention doesn't
  have a name for, and there's nothing to check that any two bindings
  that need it (there could be more than one, in other CodeMirror
  packages) will shape it the same way.
- **The warning `ocamlformat`/the compiler enforces for a trailing
  `unit ->` is stricter than CONVENTIONS.md's stated rule, and following
  the stated rule breaks the build.** CONVENTIONS.md says "the trailing
  `unit` only when every argument is optional", but `Cm_state.mli` itself
  (e.g. `EditorSelection.range`, `SelectionRange.extend`,
  `ChangeDesc.touches_range`) adds a trailing `unit` whenever an optional
  argument has no *positional* (unlabeled) argument after it anywhere in
  the signature — including cases with required labeled arguments after
  the optionals, which the stated rule doesn't call for. The real
  constraint is OCaml's own "this optional argument cannot be erased"
  warning (16), which fires whenever a definition's last optional
  argument isn't followed by a non-labeled parameter; this file follows
  that mechanical rule throughout (`layer`, `move_to_line_boundary`,
  `move_vertically`, `LayerMarker.create`, ...) rather than the written
  one, to keep the dev-profile "warnings are errors" build green. Worth
  tightening the sentence in CONVENTIONS.md.
- **Converting values across the `Cm_state`/`Cm_view` boundary needs
  explicit `to_jv`/`of_jv` far more often than working inside `Cm_state`
  itself suggests.** Inside `cm_state.ml`, `EditorState.t` and its
  siblings are literally `Jv.t` under the hood, so a same-file function
  can return `Jv.get t "state"` where an `EditorState.t` is expected and
  it just typechecks. From `cm_view.ml` — a different compilation unit
  consuming `Cm_state` only through `cm_state.mli` — every one of those
  types is properly abstract, so the exact same pattern (a bare `Jv.get`
  or a value passed straight into a `Jv.call` argument array) is a type
  error and needs an explicit `EditorState.of_jv`/`to_jv`,
  `SelectionRange.to_jv`, `Transaction.to_jv`, and so on. None of this is
  wrong — it is the abstraction working as intended — but it means the
  in-package style shown by `cm_state.ml` (freely treating its own
  forward-declared types as `Jv.t`) is not the style a *dependent*
  package should copy, and DESIGN.md's own worked example
  (`ViewUpdate.state`, `EditorView.state`, ...) reads as if it were,
  since it's written against forward types the same way `Cm_state`'s
  internals are. A short note that "once compiled, treat every other
  package's types as fully abstract, even the ones that happen to be
  `Jv.t` underneath" would have saved a full pass of build-error-driven
  fixes across this file.
- **Two of the fixed `ViewUpdate` field names don't match CodeMirror's
  own property names, without a comment saying so.** The fixed
  signature's `view_changed`/`height_changed`/... map to
  `ViewUpdate.viewportChanged`/`heightChanged`/..., i.e. `view_changed`
  is `viewportChanged` with "port" dropped — a deliberate-looking
  shortening, but nothing marks it as intentional versus a slip, and the
  fixed signature also has no `viewport_moved` for `ViewUpdate
  .viewportMoved` (added here as a plain extension, following the "bind
  the rest in the same style" instruction). A one-line note next to
  `view_changed` doc comment would remove the ambiguity for the next
  reader.
- **Not-bound items worth calling out beyond the .mli's own list**:
  `MouseSelectionStyle`/`dragMovesSelection`/`clickAddsSelectionRange`/
  `bidiIsolatedRanges`/`perLineTextDirection`/`cspNonce`/
  `focusChangeEffect`/`scrollHandler`/`clipboardInputFilter`/
  `clipboardOutputFilter`/`domEventObservers`/`gutterLineClass`/
  `gutterWidgetClass`/`lineNumberWidgetMarker`/`getDrawSelectionConfig`/
  `layer`/`RectangleMarker`/`BidiSpan` were all missing from the fixed
  signature but bound anyway per "bind the rest in the same style"; they
  added real design tension (the two points above) without being
  flagged as design-critical up front, which suggests the fixed/unfixed
  split undersells how much of the package's awkwardness lives outside
  the parts DESIGN.md pins down.
