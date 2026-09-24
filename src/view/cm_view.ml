open Cm_state

(* Forward declarations, equated inside the modules below. *)
type editor_view = Jv.t
type view_update = Jv.t
type block_info = Jv.t
type command = editor_view -> bool

type mouse_selection_style = {
  get :
    Brr.Ev.Mouse.t Brr.Ev.t -> extend:bool -> multiple:bool -> EditorSelection.t;
  update : view_update -> bool;
}

let pkg = lazy (Jv.get Jv.global "__CM__view")
let widget_type_cls = lazy (Jv.get (Lazy.force pkg) "WidgetType")
let match_decorator_cls = lazy (Jv.get (Lazy.force pkg) "MatchDecorator")
let decoration_cls = lazy (Jv.get (Lazy.force pkg) "Decoration")
let editor_view_cls = lazy (Jv.get (Lazy.force pkg) "EditorView")
let view_plugin_cls = lazy (Jv.get (Lazy.force pkg) "ViewPlugin")
let gutter_marker_cls = lazy (Jv.get (Lazy.force pkg) "GutterMarker")
let rectangle_marker_cls = lazy (Jv.get (Lazy.force pkg) "RectangleMarker")
let object_cls = lazy (Jv.get Jv.global "Object")

(* Small helpers: an absent optional argument becomes [undefined], relying
   on JavaScript's own default parameters. *)
let opt_int = Jv.of_option ~none:Jv.undefined Jv.of_int
let opt_bool = Jv.of_option ~none:Jv.undefined Jv.of_bool
let opt_float = Jv.of_option ~none:Jv.undefined Jv.of_float
let opt_jv = Jv.of_option ~none:Jv.undefined Fun.id

(* [Object.defineProperty], used to override the accessor (getter-only)
   properties of the JavaScript base classes we subclass ([WidgetType]'s
   [estimatedHeight]/[lineBreaks]): a plain [Jv.set] would either throw or
   silently fail to shadow a prototype getter that has no setter. *)
let define_prop (o : Jv.t) (name : string) (v : Jv.t) =
  let desc = Jv.obj [| ("value", v); ("configurable", Jv.true') |] in
  Jv.call (Lazy.force object_cls) "defineProperty"
    [| o; Jv.of_string name; desc |]
  |> ignore

(* [caml_js_wrap_meth_callback] unshifts the JavaScript [this] the callback
   was invoked with onto the front of the argument list; used only for
   [ViewPlugin]'s [event_handlers]/[event_observers], which CodeMirror
   invokes as [handler.call(pluginValue, event, view)] so that a single
   shared handler function can recover which view's plugin instance is
   calling it (see js/../view/bundle.js's [bindHandler]). *)
external wrap_meth_callback3 : (Jv.t -> Jv.t -> Jv.t -> Jv.t) -> Jv.t
  = "caml_js_wrap_meth_callback"

(* The hidden property under which a [ViewPlugin]'s per-view OCaml plugin
   value is stashed on the JavaScript wrapper object CodeMirror sees as
   "the plugin value". *)
let vp_a_key = "_a"

module StyleSpec = struct
  type t = (string * value) list
  and value = Value of string | Rules of t

  let rec value_to_jv = function
    | Value s -> Jv.of_string s
    | Rules r -> to_jv r

  and to_jv (t : t) : Jv.t =
    let o = Jv.obj [||] in
    List.iter (fun (k, v) -> Jv.set o k (value_to_jv v)) t;
    o
end

module ViewUpdate = struct
  type t = view_update

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let view (t : t) : editor_view = Jv.get t "view"
  let state t : EditorState.t = EditorState.of_jv (Jv.get t "state")
  let start_state t : EditorState.t = EditorState.of_jv (Jv.get t "startState")
  let changes t : ChangeSet.t = ChangeSet.of_jv (Jv.get t "changes")
  let transactions t = Jv.get t "transactions" |> Jv.to_list Transaction.of_jv
  let viewport_changed t = Jv.Bool.get t "viewportChanged"
  let viewport_moved t = Jv.Bool.get t "viewportMoved"
  let height_changed t = Jv.Bool.get t "heightChanged"
  let geometry_changed t = Jv.Bool.get t "geometryChanged"
  let focus_changed t = Jv.Bool.get t "focusChanged"
  let doc_changed t = Jv.Bool.get t "docChanged"
  let selection_set t = Jv.Bool.get t "selectionSet"
end

module WidgetType = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let make ?eq ?update_dom ?estimated_height ?line_breaks ?ignore_event
      ?coords_at ?destroy ~to_dom () : t =
    let w = Jv.new' (Lazy.force widget_type_cls) [||] in
    Jv.set w "toDOM"
      (Jv.callback ~arity:1 (fun (view : Jv.t) -> Brr.El.to_jv (to_dom view)));
    Option.iter
      (fun f ->
        Jv.set w "eq"
          (Jv.callback ~arity:1 (fun (other : Jv.t) -> Jv.of_bool (f other))))
      eq;
    Option.iter
      (fun f ->
        Jv.set w "updateDOM"
          (Jv.callback ~arity:2 (fun (dom : Jv.t) (view : Jv.t) ->
               Jv.of_bool (f (Brr.El.of_jv dom) view))))
      update_dom;
    Option.iter
      (fun h -> define_prop w "estimatedHeight" (Jv.of_int h))
      estimated_height;
    Option.iter (fun n -> define_prop w "lineBreaks" (Jv.of_int n)) line_breaks;
    Option.iter
      (fun f ->
        Jv.set w "ignoreEvent"
          (Jv.callback ~arity:1 (fun (ev : Jv.t) ->
               Jv.of_bool (f (Brr.Ev.of_jv ev)))))
      ignore_event;
    Option.iter
      (fun f ->
        Jv.set w "coordsAt"
          (Jv.callback ~arity:3 (fun (dom : Jv.t) (pos : Jv.t) (side : Jv.t) ->
               match f (Brr.El.of_jv dom) (Jv.to_int pos) (Jv.to_int side) with
               | None -> Jv.null
               | Some r -> r)))
      coords_at;
    Option.iter
      (fun f ->
        Jv.set w "destroy"
          (Jv.callback ~arity:1 (fun (dom : Jv.t) -> f (Brr.El.of_jv dom))))
      destroy;
    w

  let define (type a) ?eq ?update_dom ?estimated_height ?line_breaks
      ?ignore_event ?destroy ~to_dom () : a -> t =
    (* Every instance shares JavaScript's WidgetType constructor, so each
       class gets a token and [eq] only compares within one class. *)
    let cls = Jv.obj [||] in
    let value_of (w : Jv.t) : a option =
      if Jv.strict_equal (Jv.get w "_cls") cls then
        Some (Jv.Id.of_jv (Jv.get w "_v"))
      else None
    in
    fun (v : a) ->
      let eq =
        Option.map
          (fun f other ->
            match value_of other with Some o -> f v o | None -> false)
          eq
      in
      let w =
        make ?eq
          ?update_dom:(Option.map (fun f -> f v) update_dom)
          ?estimated_height ?line_breaks
          ?ignore_event:(Option.map (fun f -> f v) ignore_event)
          ?destroy:(Option.map (fun f -> f v) destroy)
          ~to_dom:(to_dom v) ()
      in
      Jv.set w "_cls" cls;
      Jv.set w "_v" (Jv.Id.to_jv v);
      w
end

module Direction = struct
  type t = Ltr | Rtl
end

let direction_to_int = function Direction.Ltr -> 0 | Direction.Rtl -> 1

let direction_of_int = function
  | 0 -> Direction.Ltr
  | 1 -> Direction.Rtl
  | n -> Conv.invalid "Direction" (Jv.of_int n)

module BidiSpan = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let from t = Jv.Int.get t "from"
  let to_ t = Jv.Int.get t "to"
  let level t = Jv.Int.get t "level"
  let dir t = direction_of_int (Jv.Int.get t "dir")
end

module Rect = struct
  type t = { left : float; right : float; top : float; bottom : float }

  let of_jv (jv : Jv.t) : t =
    {
      left = Jv.Float.get jv "left";
      right = Jv.Float.get jv "right";
      top = Jv.Float.get jv "top";
      bottom = Jv.Float.get jv "bottom";
    }
end

module Decoration = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  type attrs = (string * string) list

  let attrs_to_jv (a : attrs) : Jv.t =
    let o = Jv.obj [||] in
    List.iter (fun (k, v) -> Jv.set o k (Jv.of_string v)) a;
    o

  let mark ?inclusive ?inclusive_start ?inclusive_end ?attributes ?class_
      ?tag_name ?bidi_isolate () : t =
    let o = Jv.obj [||] in
    Jv.Bool.set_if_some o "inclusive" inclusive;
    Jv.Bool.set_if_some o "inclusiveStart" inclusive_start;
    Jv.Bool.set_if_some o "inclusiveEnd" inclusive_end;
    Jv.set_if_some o "attributes" (Option.map attrs_to_jv attributes);
    Jv.set_if_some o "class" (Option.map Jv.of_string class_);
    Jv.set_if_some o "tagName" (Option.map Jv.of_string tag_name);
    Jv.set_if_some o "bidiIsolate"
      (Option.map direction_to_int bidi_isolate |> Option.map Jv.of_int);
    Jv.call (Lazy.force decoration_cls) "mark" [| o |]

  let widget ?side ?inclusive ?inclusive_start ?inclusive_end ?block
      (w : WidgetType.t) : t =
    let o = Jv.obj [| ("widget", w) |] in
    Jv.Int.set_if_some o "side" side;
    Jv.Bool.set_if_some o "inclusive" inclusive;
    Jv.Bool.set_if_some o "inclusiveStart" inclusive_start;
    Jv.Bool.set_if_some o "inclusiveEnd" inclusive_end;
    Jv.Bool.set_if_some o "block" block;
    Jv.call (Lazy.force decoration_cls) "widget" [| o |]

  let replace ?widget ?inclusive ?inclusive_start ?inclusive_end ?block () : t =
    let o = Jv.obj [||] in
    Jv.set_if_some o "widget" widget;
    Jv.Bool.set_if_some o "inclusive" inclusive;
    Jv.Bool.set_if_some o "inclusiveStart" inclusive_start;
    Jv.Bool.set_if_some o "inclusiveEnd" inclusive_end;
    Jv.Bool.set_if_some o "block" block;
    Jv.call (Lazy.force decoration_cls) "replace" [| o |]

  let line ?attributes ?class_ () : t =
    let o = Jv.obj [||] in
    Jv.set_if_some o "attributes" (Option.map attrs_to_jv attributes);
    Jv.set_if_some o "class" (Option.map Jv.of_string class_);
    Jv.call (Lazy.force decoration_cls) "line" [| o |]

  let range ?to_ (t : t) ~from : t Range.t =
    Range.make conv ~from ~to_:(Option.value to_ ~default:from) t

  let none : t RangeSet.t =
    RangeSet.of_jv conv (Jv.get (Lazy.force decoration_cls) "none")

  let set ?sort (ranges : t Range.t list) : t RangeSet.t =
    RangeSet.of_ ?sort conv ranges

  let spec t = Jv.get t "spec"
end

module EditorViewConfig = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?state ?doc ?selection ?extensions ?parent ?root ?scroll_to
      ?dispatch_transactions () : t =
    let o = Jv.obj [||] in
    Jv.set_if_some o "state" (Option.map EditorState.to_jv state);
    Jv.set_if_some o "doc" (Option.map Jv.of_string doc);
    Jv.set_if_some o "selection" (Option.map EditorSelection.to_jv selection);
    Jv.set_if_some o "extensions" (Option.map Extension.to_jv extensions);
    Jv.set_if_some o "parent" (Option.map Brr.El.to_jv parent);
    Jv.set_if_some o "root" (Option.map Brr.Document.to_jv root);
    Jv.set_if_some o "scrollTo" (Option.map StateEffect.to_jv scroll_to);
    Option.iter
      (fun f ->
        let wrapped (trs : Jv.t) (view : Jv.t) =
          ignore (f (Jv.to_list Transaction.of_jv trs) view)
        in
        Jv.set o "dispatchTransactions" (Jv.callback ~arity:2 wrapped))
      dispatch_transactions;
    o
end

module MatchDecorator = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  type decoration =
    [ `Decoration of Decoration.t
    | `Of_match of string array -> editor_view -> int -> Decoration.t option ]

  let groups (m : Jv.t) : string array =
    Array.init (Jv.Int.get m "length") (fun i ->
        let g = Jv.Jarray.get m i in
        if Jv.is_undefined g then "" else Jv.to_string g)

  let create ~regexp ?decoration ?decorate ?boundary ?max_length () : t =
    let o = Jv.obj [| ("regexp", regexp) |] in
    Option.iter
      (function
        | `Decoration d -> Jv.set o "decoration" (Decoration.to_jv d)
        | `Of_match f ->
            Jv.set o "decoration"
              (Jv.callback ~arity:3 (fun m view pos ->
                   match f (groups m) view (Jv.to_int pos) with
                   | Some d -> Decoration.to_jv d
                   | None -> Jv.null)))
      decoration;
    Option.iter
      (fun f ->
        Jv.set o "decorate"
          (Jv.callback ~arity:5 (fun add from to_ m view ->
               let add ~from ~to_ d =
                 ignore
                   (Jv.apply add
                      [| Jv.of_int from; Jv.of_int to_; Decoration.to_jv d |])
               in
               f add ~from:(Jv.to_int from) ~to_:(Jv.to_int to_) (groups m) view;
               Jv.undefined)))
      decorate;
    Jv.set_if_some o "boundary" boundary;
    Jv.Int.set_if_some o "maxLength" max_length;
    Jv.new' (Lazy.force match_decorator_cls) [| o |]

  let deco_set_conv = RangeSet.conv_of Decoration.conv

  let create_deco t view =
    deco_set_conv.of_jv (Jv.call t "createDeco" [| view |])

  let update_deco t update deco =
    deco_set_conv.of_jv
      (Jv.call t "updateDeco" [| update; deco_set_conv.to_jv deco |])
end

module ViewPlugin = struct
  type 'a t = { vp_jv : Jv.t }

  let define (type a) ?update ?doc_view_update ?destroy ?decorations
      ?event_handlers ?provide (create : editor_view -> a) : a t =
    let create_wrapped (view : Jv.t) : Jv.t =
      let a_val : a = create view in
      let w = Jv.obj [||] in
      Jv.set w vp_a_key (Jv.Id.to_jv a_val);
      Option.iter
        (fun f ->
          Jv.set w "update"
            (Jv.callback ~arity:1 (fun (u : Jv.t) -> ignore (f a_val u))))
        update;
      Option.iter
        (fun f ->
          Jv.set w "docViewUpdate"
            (Jv.callback ~arity:1 (fun (v : Jv.t) -> ignore (f a_val v))))
        doc_view_update;
      Option.iter
        (fun f ->
          Jv.set w "destroy"
            (Jv.callback ~arity:1 (fun (_ : Jv.t) -> ignore (f a_val))))
        destroy;
      w
    in
    let spec = Jv.obj [||] in
    Option.iter
      (fun f ->
        let wrapped (w : Jv.t) =
          let a_val : a = Jv.Id.of_jv (Jv.get w vp_a_key) in
          RangeSet.to_jv (f a_val)
        in
        Jv.set spec "decorations" (Jv.callback ~arity:1 wrapped))
      decorations;
    Option.iter
      (fun handlers ->
        let obj = Jv.obj [||] in
        List.iter
          (fun (name, f) ->
            let wrapped =
              wrap_meth_callback3
                (fun (this_ : Jv.t) (ev : Jv.t) (view : Jv.t) ->
                  let a_val : a = Jv.Id.of_jv (Jv.get this_ vp_a_key) in
                  Jv.of_bool (f a_val (Brr.Ev.of_jv ev) view))
            in
            Jv.set obj name wrapped)
          handlers;
        Jv.set spec "eventHandlers" obj)
      event_handlers;
    Option.iter
      (fun f ->
        let wrapped (vp : Jv.t) = Extension.to_jv (f { vp_jv = vp }) in
        Jv.set spec "provide" (Jv.callback ~arity:1 wrapped))
      provide;
    let vp_jv =
      Jv.call
        (Lazy.force view_plugin_cls)
        "define"
        [| Jv.callback ~arity:1 create_wrapped; spec |]
    in
    { vp_jv }

  let extension (t : 'a t) : Extension.t =
    Extension.of_jv (Jv.get t.vp_jv "extension")
end

module EditorView = struct
  type t = editor_view

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ?config () : t =
    Jv.new' (Lazy.force editor_view_cls) [| opt_jv config |]

  let state t : EditorState.t = EditorState.of_jv (Jv.get t "state")
  let set_state t st = Jv.call t "setState" [| EditorState.to_jv st |] |> ignore

  let dispatch t (spec : TransactionSpec.t) =
    Jv.call t "dispatch" [| TransactionSpec.to_jv spec |] |> ignore

  let set_doc t doc =
    let length = Text.length (EditorState.doc (state t)) in
    dispatch t
      (TransactionSpec.create
         ~changes:(ChangeSpec.replace ~from:0 ~to_:length ~insert:doc ())
         ())

  let dispatch_all t (specs : TransactionSpec.t list) =
    Jv.call t "dispatch" (Array.of_list (List.map TransactionSpec.to_jv specs))
    |> ignore

  let dispatch_transaction t (tr : Transaction.t) =
    Jv.call t "dispatch" [| Transaction.to_jv tr |] |> ignore

  let update t (trs : Transaction.t list) =
    Jv.call t "update" [| Jv.of_list Transaction.to_jv trs |] |> ignore

  let dom t = Jv.get t "dom" |> Brr.El.of_jv
  let content_dom t = Jv.get t "contentDOM" |> Brr.El.of_jv
  let scroll_dom t = Jv.get t "scrollDOM" |> Brr.El.of_jv
  let focus t = Jv.call t "focus" [||] |> ignore
  let has_focus t = Jv.Bool.get t "hasFocus"
  let destroy t = Jv.call t "destroy" [||] |> ignore
  let request_measure t = Jv.call t "requestMeasure" [||] |> ignore
  let composing t = Jv.Bool.get t "composing"
  let in_view t = Jv.Bool.get t "inView"
  let line_wrapping t = Jv.Bool.get t "lineWrapping"
  let text_direction t = direction_of_int (Jv.Int.get t "textDirection")

  let viewport t =
    let v = Jv.get t "viewport" in
    (Jv.Int.get v "from", Jv.Int.get v "to")

  let visible_ranges t =
    Jv.get t "visibleRanges"
    |> Jv.to_list (fun r -> (Jv.Int.get r "from", Jv.Int.get r "to"))

  let pos_at_coords ?precise t ~x ~y =
    let coords = Jv.obj [| ("x", Jv.of_float x); ("y", Jv.of_float y) |] in
    match precise with
    | Some false ->
        Some (Jv.to_int (Jv.call t "posAtCoords" [| coords; Jv.false' |]))
    | _ ->
        let r = Jv.call t "posAtCoords" [| coords |] in
        if Jv.is_null r then None else Some (Jv.to_int r)

  let coords_at_pos ?side t pos =
    let r = Jv.call t "coordsAtPos" [| Jv.of_int pos; opt_int side |] in
    if Jv.is_null r then None else Some r

  let default_line_height t = Jv.Float.get t "defaultLineHeight"
  let default_character_width t = Jv.Float.get t "defaultCharacterWidth"

  let plugin (type a) (t : t) (vp : a ViewPlugin.t) : a option =
    let r = Jv.call t "plugin" [| vp.ViewPlugin.vp_jv |] in
    if Jv.is_null r then None else Some (Jv.Id.of_jv (Jv.get r vp_a_key))

  let composition_started t = Jv.Bool.get t "compositionStarted"
  let theme_classes t = Jv.Jstr.get t "themeClasses" |> Jstr.to_string
  let document_top t = Jv.Float.get t "documentTop"

  let document_padding t =
    let p = Jv.get t "documentPadding" in
    (Jv.Float.get p "top", Jv.Float.get p "bottom")

  let scale_x t = Jv.Float.get t "scaleX"
  let scale_y t = Jv.Float.get t "scaleY"

  let element_at_height t h : block_info =
    Jv.call t "elementAtHeight" [| Jv.of_float h |]

  let line_block_at_height t h : block_info =
    Jv.call t "lineBlockAtHeight" [| Jv.of_float h |]

  let viewport_line_blocks t : block_info list =
    Jv.get t "viewportLineBlocks" |> Jv.to_list Fun.id

  let line_block_at t pos : block_info =
    Jv.call t "lineBlockAt" [| Jv.of_int pos |]

  let content_height t = Jv.Float.get t "contentHeight"

  let move_by_char t (start : SelectionRange.t) forward ?by () :
      SelectionRange.t =
    let by_jv =
      match by with
      | None -> Jv.undefined
      | Some f ->
          Jv.callback ~arity:1 (fun (initial : Jv.t) ->
              Jv.callback ~arity:1 (fun (next : Jv.t) ->
                  Jv.of_bool (f (Jv.to_string initial) (Jv.to_string next))))
    in
    Jv.call t "moveByChar"
      [| SelectionRange.to_jv start; Jv.of_bool forward; by_jv |]
    |> SelectionRange.of_jv

  let move_by_group t (start : SelectionRange.t) forward : SelectionRange.t =
    Jv.call t "moveByGroup" [| SelectionRange.to_jv start; Jv.of_bool forward |]
    |> SelectionRange.of_jv

  let visual_line_side t (line : Line.t) end_ : SelectionRange.t =
    Jv.call t "visualLineSide" [| Line.to_jv line; Jv.of_bool end_ |]
    |> SelectionRange.of_jv

  let move_to_line_boundary t (start : SelectionRange.t) forward ?include_wrap
      () : SelectionRange.t =
    Jv.call t "moveToLineBoundary"
      [|
        SelectionRange.to_jv start; Jv.of_bool forward; opt_bool include_wrap;
      |]
    |> SelectionRange.of_jv

  let move_vertically t (start : SelectionRange.t) forward ?distance () :
      SelectionRange.t =
    Jv.call t "moveVertically"
      [| SelectionRange.to_jv start; Jv.of_bool forward; opt_float distance |]
    |> SelectionRange.of_jv

  let dom_at_pos t pos =
    let r = Jv.call t "domAtPos" [| Jv.of_int pos |] in
    (Jv.get r "node" |> Brr.El.of_jv, Jv.Int.get r "offset")

  let pos_at_dom t ?offset (node : Brr.El.t) =
    Jv.call t "posAtDOM" [| Brr.El.to_jv node; opt_int offset |] |> Jv.to_int

  let coords_for_char t pos =
    let r = Jv.call t "coordsForChar" [| Jv.of_int pos |] in
    if Jv.is_null r then None else Some (Rect.of_jv r)

  let text_direction_at t pos =
    direction_of_int
      (Jv.to_int (Jv.call t "textDirectionAt" [| Jv.of_int pos |]))

  let bidi_spans t (line : Line.t) =
    Jv.call t "bidiSpans" [| Line.to_jv line |] |> Jv.to_list Fun.id

  let set_root t (doc : Brr.Document.t) =
    Jv.call t "setRoot" [| Brr.Document.to_jv doc |] |> ignore

  let scroll_snapshot t : StateEffect.t =
    StateEffect.of_jv (Jv.call t "scrollSnapshot" [||])

  let set_tab_focus_mode ?to_ t =
    let arg =
      match to_ with
      | None -> Jv.undefined
      | Some (`Bool b) -> Jv.of_bool b
      | Some (`Ms n) -> Jv.of_int n
    in
    Jv.call t "setTabFocusMode" [| arg |] |> ignore

  (* statics: fixed part *)
  let theme ?dark (spec : StyleSpec.t) : Extension.t =
    let o = Jv.obj [||] in
    Jv.Bool.set_if_some o "dark" dark;
    Extension.of_jv
      (Jv.call
         (Lazy.force editor_view_cls)
         "theme"
         [| StyleSpec.to_jv spec; o |])

  let base_theme (spec : StyleSpec.t) : Extension.t =
    Extension.of_jv
      (Jv.call
         (Lazy.force editor_view_cls)
         "baseTheme"
         [| StyleSpec.to_jv spec |])

  let line_wrapping_extension : Extension.t =
    Extension.of_jv (Jv.get (Lazy.force editor_view_cls) "lineWrapping")

  let editable =
    Facet.of_jv Conv.bool Conv.bool
      (Jv.get (Lazy.force editor_view_cls) "editable")

  let dark_theme =
    Facet.of_jv Conv.bool Conv.bool
      (Jv.get (Lazy.force editor_view_cls) "darkTheme")

  let decorations =
    Facet.of_jv
      (RangeSet.conv_of Decoration.conv)
      Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "decorations")

  let outer_decorations =
    Facet.of_jv
      (RangeSet.conv_of Decoration.conv)
      Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "outerDecorations")

  let atomic_ranges_conv : (editor_view -> Decoration.t RangeSet.t) Conv.t =
    {
      Conv.to_jv =
        (fun f -> Jv.callback ~arity:1 (fun (v : Jv.t) -> RangeSet.to_jv (f v)));
      of_jv =
        (fun jv (v : editor_view) ->
          RangeSet.of_jv Decoration.conv (Jv.apply jv [| v |]));
    }

  let atomic_ranges =
    Facet.of_jv atomic_ranges_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "atomicRanges")

  let update_listener_conv : (view_update -> unit) Conv.t =
    {
      Conv.to_jv = (fun f -> Jv.callback ~arity:1 (fun (u : Jv.t) -> f u));
      of_jv = (fun jv (u : view_update) -> Jv.apply jv [| u |] |> ignore);
    }

  let update_listener =
    Facet.of_jv update_listener_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "updateListener")

  let dom_event_handlers handlers : Extension.t =
    let o = Jv.obj [||] in
    List.iter
      (fun (name, f) ->
        let wrapped (ev : Jv.t) (view : Jv.t) =
          Jv.of_bool (f (Brr.Ev.of_jv ev) view)
        in
        Jv.set o name (Jv.callback ~arity:2 wrapped))
      handlers;
    Extension.of_jv
      (Jv.call (Lazy.force editor_view_cls) "domEventHandlers" [| o |])

  let input_handler_conv :
      (editor_view -> from:int -> to_:int -> string -> bool) Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          Jv.callback ~arity:5
            (fun
              (view : Jv.t)
              (from : Jv.t)
              (to_ : Jv.t)
              (text : Jv.t)
              (_insert : Jv.t)
            ->
              Jv.of_bool
                (f view ~from:(Jv.to_int from) ~to_:(Jv.to_int to_)
                   (Jv.to_string text))));
      of_jv =
        (fun jv (view : editor_view) ~from ~to_ (text : string) ->
          Jv.apply jv
            [|
              view;
              Jv.of_int from;
              Jv.of_int to_;
              Jv.of_string text;
              Jv.undefined;
            |]
          |> Jv.to_bool);
    }

  let input_handler =
    Facet.of_jv input_handler_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "inputHandler")

  let attrs_conv : (string * string) list Conv.t =
    {
      Conv.to_jv = Decoration.attrs_to_jv;
      of_jv =
        (fun jv ->
          let keys =
            Jv.call (Lazy.force object_cls) "keys" [| jv |]
            |> Jv.to_list Jv.to_string
          in
          List.map (fun k -> (k, Jv.to_string (Jv.get jv k))) keys);
    }

  let content_attributes =
    Facet.of_jv attrs_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "contentAttributes")

  let editor_attributes =
    Facet.of_jv attrs_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "editorAttributes")

  let scroll_margins_conv : (editor_view -> Jv.t option) Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          Jv.callback ~arity:1 (fun (v : Jv.t) ->
              match f v with None -> Jv.null | Some r -> r));
      of_jv =
        (fun jv (v : editor_view) ->
          let r = Jv.apply jv [| v |] in
          if Jv.is_null r then None else Some r);
    }

  let scroll_margins =
    Facet.of_jv scroll_margins_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "scrollMargins")

  let exception_sink_conv : (Jv.t -> unit) Conv.t =
    {
      Conv.to_jv = (fun f -> Jv.callback ~arity:1 (fun (e : Jv.t) -> f e));
      of_jv = (fun jv (e : Jv.t) -> Jv.apply jv [| e |] |> ignore);
    }

  let exception_sink =
    Facet.of_jv exception_sink_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "exceptionSink")

  (* The real effect type CodeMirror dispatches, not a fresh one: defining
     our own would never match in [StateEffect.is]. *)
  let announce : string StateEffectType.t =
    StateEffectType.of_jv Conv.string
      (Jv.get (Lazy.force editor_view_cls) "announce")

  let scroll_into_view ?y ?x ?y_margin ?x_margin pos : StateEffect.t =
    let o = Jv.obj [||] in
    Jv.set_if_some o "y" (Option.map Jv.of_string y);
    Jv.set_if_some o "x" (Option.map Jv.of_string x);
    Jv.Int.set_if_some o "yMargin" y_margin;
    Jv.Int.set_if_some o "xMargin" x_margin;
    StateEffect.of_jv
      (Jv.call
         (Lazy.force editor_view_cls)
         "scrollIntoView"
         [| Jv.of_int pos; o |])

  let find_from_dom (dom : Brr.El.t) : t option =
    let r =
      Jv.call (Lazy.force editor_view_cls) "findFromDOM" [| Brr.El.to_jv dom |]
    in
    if Jv.is_null r then None else Some r

  (* statics: the rest of the exported surface *)
  let dom_event_observers handlers : Extension.t =
    let o = Jv.obj [||] in
    List.iter
      (fun (name, f) ->
        let wrapped (ev : Jv.t) (view : Jv.t) =
          f (Brr.Ev.of_jv ev) view;
          Jv.undefined
        in
        Jv.set o name (Jv.callback ~arity:2 wrapped))
      handlers;
    Extension.of_jv
      (Jv.call (Lazy.force editor_view_cls) "domEventObservers" [| o |])

  let clipboard_filter_conv : (string -> EditorState.t -> string) Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          Jv.callback ~arity:2 (fun (text : Jv.t) (st : Jv.t) ->
              Jv.of_string (f (Jv.to_string text) (EditorState.of_jv st))));
      of_jv =
        (fun jv (text : string) (st : EditorState.t) ->
          Jv.apply jv [| Jv.of_string text; EditorState.to_jv st |]
          |> Jv.to_string);
    }

  let clipboard_input_filter =
    Facet.of_jv clipboard_filter_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "clipboardInputFilter")

  let clipboard_output_filter =
    Facet.of_jv clipboard_filter_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "clipboardOutputFilter")

  let scroll_handler_conv :
      (editor_view ->
      SelectionRange.t ->
      x:string ->
      y:string ->
      x_margin:int ->
      y_margin:int ->
      bool)
      Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          Jv.callback ~arity:3
            (fun (view : Jv.t) (range : Jv.t) (opts : Jv.t) ->
              Jv.of_bool
                (f view
                   (SelectionRange.of_jv range)
                   ~x:(Jv.to_string (Jv.get opts "x"))
                   ~y:(Jv.to_string (Jv.get opts "y"))
                   ~x_margin:(Jv.Int.get opts "xMargin")
                   ~y_margin:(Jv.Int.get opts "yMargin"))));
      of_jv =
        (fun jv
          (view : editor_view)
          (range : SelectionRange.t)
          ~x
          ~y
          ~x_margin
          ~y_margin
        ->
          let opts =
            Jv.obj
              [|
                ("x", Jv.of_string x);
                ("y", Jv.of_string y);
                ("xMargin", Jv.of_int x_margin);
                ("yMargin", Jv.of_int y_margin);
              |]
          in
          Jv.apply jv [| view; SelectionRange.to_jv range; opts |] |> Jv.to_bool);
    }

  let scroll_handler =
    Facet.of_jv scroll_handler_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "scrollHandler")

  let focus_change_effect_conv :
      (EditorState.t -> focusing:bool -> StateEffect.t option) Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          Jv.callback ~arity:2 (fun (st : Jv.t) (focusing : Jv.t) ->
              match
                f (EditorState.of_jv st) ~focusing:(Jv.to_bool focusing)
              with
              | None -> Jv.null
              | Some e -> StateEffect.to_jv e));
      of_jv =
        (fun jv (st : EditorState.t) ~focusing ->
          let r = Jv.apply jv [| EditorState.to_jv st; Jv.of_bool focusing |] in
          if Jv.is_null r then None else Some (StateEffect.of_jv r));
    }

  let focus_change_effect =
    Facet.of_jv focus_change_effect_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "focusChangeEffect")

  let per_line_text_direction =
    Facet.of_jv Conv.bool Conv.bool
      (Jv.get (Lazy.force editor_view_cls) "perLineTextDirection")

  let mouse_selection_style_value_conv : mouse_selection_style Conv.t =
    {
      Conv.to_jv =
        (fun (m : mouse_selection_style) ->
          let o = Jv.obj [||] in
          Jv.set o "get"
            (Jv.callback ~arity:3
               (fun (ev : Jv.t) (extend : Jv.t) (multiple : Jv.t) ->
                 EditorSelection.to_jv
                   (m.get (Brr.Ev.of_jv ev) ~extend:(Jv.to_bool extend)
                      ~multiple:(Jv.to_bool multiple))));
          Jv.set o "update"
            (Jv.callback ~arity:1 (fun (u : Jv.t) -> Jv.of_bool (m.update u)));
          o);
      of_jv =
        (fun jv ->
          {
            get =
              (fun ev ~extend ~multiple ->
                Jv.call jv "get"
                  [| Brr.Ev.to_jv ev; Jv.of_bool extend; Jv.of_bool multiple |]
                |> EditorSelection.of_jv);
            update = (fun u -> Jv.call jv "update" [| u |] |> Jv.to_bool);
          });
    }

  let mouse_selection_style_conv :
      (editor_view -> Brr.Ev.Mouse.t Brr.Ev.t -> mouse_selection_style option)
      Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          Jv.callback ~arity:2 (fun (view : Jv.t) (ev : Jv.t) ->
              match f view (Brr.Ev.of_jv ev) with
              | None -> Jv.null
              | Some m -> mouse_selection_style_value_conv.to_jv m));
      of_jv =
        (fun jv (view : editor_view) (ev : Brr.Ev.Mouse.t Brr.Ev.t) ->
          let r = Jv.apply jv [| view; Brr.Ev.to_jv ev |] in
          if Jv.is_null r then None
          else Some (mouse_selection_style_value_conv.of_jv r));
    }

  let mouse_selection_style =
    Facet.of_jv mouse_selection_style_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "mouseSelectionStyle")

  let mouse_bool_conv : (Brr.Ev.Mouse.t Brr.Ev.t -> bool) Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          Jv.callback ~arity:1 (fun (ev : Jv.t) ->
              Jv.of_bool (f (Brr.Ev.of_jv ev))));
      of_jv =
        (fun jv (ev : Brr.Ev.Mouse.t Brr.Ev.t) ->
          Jv.apply jv [| Brr.Ev.to_jv ev |] |> Jv.to_bool);
    }

  let drag_moves_selection =
    Facet.of_jv mouse_bool_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "dragMovesSelection")

  let click_adds_selection_range =
    Facet.of_jv mouse_bool_conv Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "clickAddsSelectionRange")

  let bidi_isolated_ranges =
    Facet.of_jv
      (RangeSet.conv_of Decoration.conv)
      Conv.jv
      (Jv.get (Lazy.force editor_view_cls) "bidiIsolatedRanges")

  let csp_nonce =
    Facet.of_jv Conv.string Conv.string
      (Jv.get (Lazy.force editor_view_cls) "cspNonce")
end

module KeyBinding = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let command_to_jv (f : command) =
    Jv.callback ~arity:1 (fun (view : Jv.t) -> Jv.of_bool (f view))

  let create ?key ?mac ?win ?linux ?run ?shift ?any ?scope ?prevent_default
      ?stop_propagation () : t =
    let o = Jv.obj [||] in
    Jv.set_if_some o "key" (Option.map Jv.of_string key);
    Jv.set_if_some o "mac" (Option.map Jv.of_string mac);
    Jv.set_if_some o "win" (Option.map Jv.of_string win);
    Jv.set_if_some o "linux" (Option.map Jv.of_string linux);
    Jv.set_if_some o "run" (Option.map command_to_jv run);
    Jv.set_if_some o "shift" (Option.map command_to_jv shift);
    Option.iter
      (fun f ->
        Jv.set o "any"
          (Jv.callback ~arity:2 (fun (view : Jv.t) (ev : Jv.t) ->
               Jv.of_bool (f view (Brr.Ev.of_jv ev)))))
      any;
    Jv.set_if_some o "scope" (Option.map Jv.of_string scope);
    Jv.Bool.set_if_some o "preventDefault" prevent_default;
    Jv.Bool.set_if_some o "stopPropagation" stop_propagation;
    o
end

let key_binding_conv : KeyBinding.t Conv.t =
  Conv.{ to_jv = KeyBinding.to_jv; of_jv = KeyBinding.of_jv }

let keymap : (KeyBinding.t list, Jv.t) Facet.t =
  Facet.of_jv
    (Conv.list key_binding_conv)
    Conv.jv
    (Jv.get (Lazy.force pkg) "keymap")

let run_scope_handlers (view : editor_view) (ev : Brr.Ev.Keyboard.t Brr.Ev.t)
    (scope : string) : bool =
  Jv.call (Lazy.force pkg) "runScopeHandlers"
    [| view; Brr.Ev.to_jv ev; Jv.of_string scope |]
  |> Jv.to_bool

module GutterMarker = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let make ?eq ?element_class ?destroy ~to_dom () : t =
    let m = Jv.new' (Lazy.force gutter_marker_cls) [||] in
    Jv.set m "toDOM"
      (Jv.callback ~arity:1 (fun (view : Jv.t) -> Brr.El.to_jv (to_dom view)));
    Option.iter
      (fun f ->
        Jv.set m "eq"
          (Jv.callback ~arity:1 (fun (other : Jv.t) -> Jv.of_bool (f other))))
      eq;
    Option.iter
      (fun c -> Jv.set m "elementClass" (Jv.of_string c))
      element_class;
    Option.iter
      (fun f ->
        Jv.set m "destroy"
          (Jv.callback ~arity:1 (fun (dom : Jv.t) -> f (Brr.El.of_jv dom))))
      destroy;
    m

  let range ?to_ (t : t) ~from : t Range.t =
    Range.make conv ~from ~to_:(Option.value to_ ~default:from) t
end

module BlockType = struct
  type t = Text | Widget_before | Widget_after | Widget_range
end

let block_type_of_int = function
  | 0 -> BlockType.Text
  | 1 -> BlockType.Widget_before
  | 2 -> BlockType.Widget_after
  | 3 -> BlockType.Widget_range
  | n -> Conv.invalid "BlockType" (Jv.of_int n)

module BlockInfo = struct
  type t = block_info

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let from t = Jv.Int.get t "from"
  let to_ t = Jv.Int.get t "to"
  let length t = Jv.Int.get t "length"
  let top t = Jv.Float.get t "top"
  let bottom t = Jv.Float.get t "bottom"
  let height t = Jv.Float.get t "height"

  let type_ t : [ `Type of BlockType.t | `Blocks of t list ] =
    let v = Jv.get t "type" in
    if Jv.is_array v then `Blocks (Jv.to_list Fun.id v)
    else `Type (block_type_of_int (Jv.to_int v))

  let widget t : WidgetType.t option =
    let w = Jv.get t "widget" in
    if Jv.is_null w then None else Some w

  let widget_line_breaks t = Jv.Int.get t "widgetLineBreaks"
end

let gutter ?class_ ?markers ?line_marker ?widget_marker ?line_marker_change
    ?initial_spacer ?update_spacer ?dom_event_handlers () : Extension.t =
  let o = Jv.obj [||] in
  Jv.set_if_some o "class" (Option.map Jv.of_string class_);
  Option.iter
    (fun f ->
      let wrapped (view : Jv.t) = RangeSet.to_jv (f view) in
      Jv.set o "markers" (Jv.callback ~arity:1 wrapped))
    markers;
  Option.iter
    (fun f ->
      let wrapped (view : Jv.t) (line : Jv.t) (others : Jv.t) =
        match f view line (Jv.to_list Fun.id others) with
        | None -> Jv.null
        | Some m -> m
      in
      Jv.set o "lineMarker" (Jv.callback ~arity:3 wrapped))
    line_marker;
  Option.iter
    (fun f ->
      let wrapped (view : Jv.t) (widget : Jv.t) (block : Jv.t) =
        match f view widget block with None -> Jv.null | Some m -> m
      in
      Jv.set o "widgetMarker" (Jv.callback ~arity:3 wrapped))
    widget_marker;
  Option.iter
    (fun f ->
      let wrapped (u : Jv.t) = Jv.of_bool (f u) in
      Jv.set o "lineMarkerChange" (Jv.callback ~arity:1 wrapped))
    line_marker_change;
  Option.iter
    (fun f ->
      let wrapped (view : Jv.t) = f view in
      Jv.set o "initialSpacer" (Jv.callback ~arity:1 wrapped))
    initial_spacer;
  Option.iter
    (fun f ->
      let wrapped (spacer : Jv.t) (u : Jv.t) = f spacer u in
      Jv.set o "updateSpacer" (Jv.callback ~arity:2 wrapped))
    update_spacer;
  Option.iter
    (fun handlers ->
      let handlers_obj = Jv.obj [||] in
      List.iter
        (fun (name, f) ->
          let wrapped (view : Jv.t) (line : Jv.t) (ev : Jv.t) =
            Jv.of_bool (f view line (Brr.Ev.of_jv ev))
          in
          Jv.set handlers_obj name (Jv.callback ~arity:3 wrapped))
        handlers;
      Jv.set o "domEventHandlers" handlers_obj)
    dom_event_handlers;
  Extension.of_jv (Jv.call (Lazy.force pkg) "gutter" [| o |])

let gutters ?fixed () : Extension.t =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "fixed" fixed;
  Extension.of_jv (Jv.call (Lazy.force pkg) "gutters" [| o |])

let line_numbers ?format_number ?dom_event_handlers () : Extension.t =
  let o = Jv.obj [||] in
  Option.iter
    (fun f ->
      let wrapped (n : Jv.t) (st : Jv.t) =
        Jv.of_string (f (Jv.to_int n) (EditorState.of_jv st))
      in
      Jv.set o "formatNumber" (Jv.callback ~arity:2 wrapped))
    format_number;
  Option.iter
    (fun handlers ->
      let handlers_obj = Jv.obj [||] in
      List.iter
        (fun (name, f) ->
          let wrapped (view : Jv.t) (line : Jv.t) (ev : Jv.t) =
            Jv.of_bool (f view line (Brr.Ev.of_jv ev))
          in
          Jv.set handlers_obj name (Jv.callback ~arity:3 wrapped))
        handlers;
      Jv.set o "domEventHandlers" handlers_obj)
    dom_event_handlers;
  Extension.of_jv (Jv.call (Lazy.force pkg) "lineNumbers" [| o |])

let line_number_markers : (GutterMarker.t RangeSet.t, Jv.t) Facet.t =
  Facet.of_jv
    (RangeSet.conv_of GutterMarker.conv)
    Conv.jv
    (Jv.get (Lazy.force pkg) "lineNumberMarkers")

let gutter_line_class : (GutterMarker.t RangeSet.t, Jv.t) Facet.t =
  Facet.of_jv
    (RangeSet.conv_of GutterMarker.conv)
    Conv.jv
    (Jv.get (Lazy.force pkg) "gutterLineClass")

let gutter_widget_marker_conv :
    (editor_view -> WidgetType.t -> BlockInfo.t -> GutterMarker.t option) Conv.t
    =
  {
    Conv.to_jv =
      (fun f ->
        Jv.callback ~arity:3
          (fun (view : Jv.t) (widget : Jv.t) (block : Jv.t) ->
            match f view widget block with None -> Jv.null | Some m -> m));
    of_jv =
      (fun jv
        (view : editor_view)
        (widget : WidgetType.t)
        (block : BlockInfo.t)
      ->
        let r = Jv.apply jv [| view; widget; block |] in
        if Jv.is_null r then None else Some r);
  }

let gutter_widget_class :
    ( editor_view -> WidgetType.t -> BlockInfo.t -> GutterMarker.t option,
      Jv.t )
    Facet.t =
  Facet.of_jv gutter_widget_marker_conv Conv.jv
    (Jv.get (Lazy.force pkg) "gutterWidgetClass")

let line_number_widget_marker :
    ( editor_view -> WidgetType.t -> BlockInfo.t -> GutterMarker.t option,
      Jv.t )
    Facet.t =
  Facet.of_jv gutter_widget_marker_conv Conv.jv
    (Jv.get (Lazy.force pkg) "lineNumberWidgetMarker")

let highlight_active_line_gutter () : Extension.t =
  Extension.of_jv (Jv.call (Lazy.force pkg) "highlightActiveLineGutter" [||])

module Panel = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?mount ?update ?destroy ?top (dom : Brr.El.t) : t =
    let o = Jv.obj [| ("dom", Brr.El.to_jv dom) |] in
    Option.iter
      (fun f ->
        Jv.set o "mount" (Jv.callback ~arity:1 (fun (_ : Jv.t) -> f ())))
      mount;
    Option.iter
      (fun f ->
        Jv.set o "update" (Jv.callback ~arity:1 (fun (u : Jv.t) -> f u)))
      update;
    Option.iter
      (fun f ->
        Jv.set o "destroy" (Jv.callback ~arity:1 (fun (_ : Jv.t) -> f ())))
      destroy;
    Jv.Bool.set_if_some o "top" top;
    o

  let dom t = Jv.get t "dom" |> Brr.El.of_jv
end

let panel_constructor_conv : (editor_view -> Panel.t) option Conv.t =
  {
    Conv.to_jv =
      (function
      | None -> Jv.null
      | Some f -> Jv.callback ~arity:1 (fun (view : Jv.t) -> f view));
    of_jv =
      (fun jv ->
        if Jv.is_none jv then None
        else Some (fun (view : editor_view) -> Jv.apply jv [| view |]));
  }

let show_panel : ((editor_view -> Panel.t) option, Jv.t) Facet.t =
  Facet.of_jv panel_constructor_conv Conv.jv
    (Jv.get (Lazy.force pkg) "showPanel")

let panels ?top_container ?bottom_container () : Extension.t =
  let o = Jv.obj [||] in
  Jv.set_if_some o "topContainer" (Option.map Brr.El.to_jv top_container);
  Jv.set_if_some o "bottomContainer" (Option.map Brr.El.to_jv bottom_container);
  Extension.of_jv (Jv.call (Lazy.force pkg) "panels" [| o |])

let get_panel (view : editor_view) (ctor : editor_view -> Panel.t) :
    Panel.t option =
  let ctor_jv = panel_constructor_conv.to_jv (Some ctor) in
  let r = Jv.call (Lazy.force pkg) "getPanel" [| view; ctor_jv |] in
  if Jv.is_null r then None else Some r

module TooltipView = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?offset ?overlap ?mount ?update ?destroy ?positioned ?resize
      (dom : Brr.El.t) : t =
    let o = Jv.obj [| ("dom", Brr.El.to_jv dom) |] in
    Option.iter
      (fun (x, y) ->
        Jv.set o "offset" (Jv.obj [| ("x", Jv.of_int x); ("y", Jv.of_int y) |]))
      offset;
    Jv.Bool.set_if_some o "overlap" overlap;
    Option.iter
      (fun f ->
        Jv.set o "mount" (Jv.callback ~arity:1 (fun (view : Jv.t) -> f view)))
      mount;
    Option.iter
      (fun f ->
        Jv.set o "update" (Jv.callback ~arity:1 (fun (u : Jv.t) -> f u)))
      update;
    Option.iter
      (fun f ->
        Jv.set o "destroy" (Jv.callback ~arity:1 (fun (_ : Jv.t) -> f ())))
      destroy;
    Option.iter
      (fun f ->
        Jv.set o "positioned"
          (Jv.callback ~arity:1 (fun (space : Jv.t) -> f space)))
      positioned;
    Jv.Bool.set_if_some o "resize" resize;
    o

  let dom t = Jv.get t "dom" |> Brr.El.of_jv
end

module Tooltip = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?end_ ?above ?strict_side ?arrow ?clip ~pos ~create:mk () : t =
    let o = Jv.obj [| ("pos", Jv.of_int pos) |] in
    Jv.Int.set_if_some o "end" end_;
    Jv.set o "create" (Jv.callback ~arity:1 (fun (view : Jv.t) -> mk view));
    Jv.Bool.set_if_some o "above" above;
    Jv.Bool.set_if_some o "strictSide" strict_side;
    Jv.Bool.set_if_some o "arrow" arrow;
    Jv.Bool.set_if_some o "clip" clip;
    o

  let pos t = Jv.Int.get t "pos"
  let end_ t = Jv.Int.find t "end"
end

let tooltip_conv : Tooltip.t Conv.t =
  Conv.{ to_jv = Tooltip.to_jv; of_jv = Tooltip.of_jv }

let show_tooltip : (Tooltip.t option, Jv.t) Facet.t =
  Facet.of_jv (Conv.option tooltip_conv) Conv.jv
    (Jv.get (Lazy.force pkg) "showTooltip")

let hover_tooltip ?hide_on_change ?hover_time
    (source : editor_view -> pos:int -> side:int -> Tooltip.t option Fut.t) :
    Extension.t =
  let wrapped (view : Jv.t) (pos : Jv.t) (side : Jv.t) =
    source view ~pos:(Jv.to_int pos) ~side:(Jv.to_int side)
    |> Async.promise_of_fut (function
         | None -> Jv.null
         | Some t -> Tooltip.to_jv t)
  in
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "hideOnChange" hide_on_change;
  Jv.Int.set_if_some o "hoverTime" hover_time;
  Extension.of_jv
    (Jv.call (Lazy.force pkg) "hoverTooltip"
       [| Jv.callback ~arity:3 wrapped; o |])

let tooltips ?position ?parent ?tooltip_space () : Extension.t =
  let o = Jv.obj [||] in
  Jv.set_if_some o "position" (Option.map Jv.of_string position);
  Jv.set_if_some o "parent" (Option.map Brr.El.to_jv parent);
  Option.iter
    (fun f ->
      Jv.set o "tooltipSpace"
        (Jv.callback ~arity:1 (fun (view : Jv.t) -> f view)))
    tooltip_space;
  Extension.of_jv (Jv.call (Lazy.force pkg) "tooltips" [| o |])

let get_tooltip (view : editor_view) (tt : Tooltip.t) : TooltipView.t option =
  let r = Jv.call (Lazy.force pkg) "getTooltip" [| view; tt |] in
  if Jv.is_null r then None else Some r

let has_hover_tooltips (st : EditorState.t) : bool =
  Jv.call (Lazy.force pkg) "hasHoverTooltips" [| EditorState.to_jv st |]
  |> Jv.to_bool

let close_hover_tooltips : StateEffect.t =
  StateEffect.of_jv (Jv.get (Lazy.force pkg) "closeHoverTooltips")

let reposition_tooltips (view : editor_view) : unit =
  Jv.call (Lazy.force pkg) "repositionTooltips" [| view |] |> ignore

let draw_selection ?cursor_blink_rate ?draw_range_cursor () : Extension.t =
  let o = Jv.obj [||] in
  Jv.Int.set_if_some o "cursorBlinkRate" cursor_blink_rate;
  Jv.Bool.set_if_some o "drawRangeCursor" draw_range_cursor;
  Extension.of_jv (Jv.call (Lazy.force pkg) "drawSelection" [| o |])

type selection_config = { cursor_blink_rate : int; draw_range_cursor : bool }

let get_draw_selection_config (st : EditorState.t) : selection_config =
  let r =
    Jv.call (Lazy.force pkg) "getDrawSelectionConfig" [| EditorState.to_jv st |]
  in
  {
    cursor_blink_rate = Jv.Int.get r "cursorBlinkRate";
    draw_range_cursor = Jv.Bool.get r "drawRangeCursor";
  }

let drop_cursor () : Extension.t =
  Extension.of_jv (Jv.call (Lazy.force pkg) "dropCursor" [||])

let highlight_active_line () : Extension.t =
  Extension.of_jv (Jv.call (Lazy.force pkg) "highlightActiveLine" [||])

let highlight_special_chars ?render ?special_chars ?add_special_chars () :
    Extension.t =
  let o = Jv.obj [||] in
  Option.iter
    (fun f ->
      let wrapped (code : Jv.t) (desc : Jv.t) (placeholder : Jv.t) =
        Brr.El.to_jv
          (f (Jv.to_int code)
             (if Jv.is_null desc then None else Some (Jv.to_string desc))
             (Jv.to_string placeholder))
      in
      Jv.set o "render" (Jv.callback ~arity:3 wrapped))
    render;
  Jv.set_if_some o "specialChars" special_chars;
  Jv.set_if_some o "addSpecialChars" add_special_chars;
  Extension.of_jv (Jv.call (Lazy.force pkg) "highlightSpecialChars" [| o |])

let highlight_whitespace () : Extension.t =
  Extension.of_jv (Jv.call (Lazy.force pkg) "highlightWhitespace" [||])

let highlight_trailing_whitespace () : Extension.t =
  Extension.of_jv (Jv.call (Lazy.force pkg) "highlightTrailingWhitespace" [||])

let placeholder (content : [ `Text of string | `El of Brr.El.t ]) : Extension.t
    =
  let jv =
    match content with `Text s -> Jv.of_string s | `El e -> Brr.El.to_jv e
  in
  Extension.of_jv (Jv.call (Lazy.force pkg) "placeholder" [| jv |])

let rectangular_selection ?event_filter () : Extension.t =
  let o = Jv.obj [||] in
  Option.iter
    (fun f ->
      Jv.set o "eventFilter"
        (Jv.callback ~arity:1 (fun (ev : Jv.t) ->
             Jv.of_bool (f (Brr.Ev.of_jv ev)))))
    event_filter;
  Extension.of_jv (Jv.call (Lazy.force pkg) "rectangularSelection" [| o |])

let crosshair_cursor ?key () : Extension.t =
  let o = Jv.obj [||] in
  Jv.set_if_some o "key" (Option.map Jv.of_string key);
  Extension.of_jv (Jv.call (Lazy.force pkg) "crosshairCursor" [| o |])

let scroll_past_end () : Extension.t =
  Extension.of_jv (Jv.call (Lazy.force pkg) "scrollPastEnd" [||])

let log_exception (st : EditorState.t) (exn : Jv.t) : unit =
  Jv.call (Lazy.force pkg) "logException" [| EditorState.to_jv st; exn |]
  |> ignore

module LayerMarker = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?update ~eq ~draw () : t =
    let o = Jv.obj [||] in
    Jv.set o "eq"
      (Jv.callback ~arity:1 (fun (other : Jv.t) -> Jv.of_bool (eq other)));
    Jv.set o "draw"
      (Jv.callback ~arity:1 (fun (_ : Jv.t) -> Brr.El.to_jv (draw ())));
    Option.iter
      (fun f ->
        Jv.set o "update"
          (Jv.callback ~arity:2 (fun (dom : Jv.t) (old : Jv.t) ->
               Jv.of_bool (f (Brr.El.of_jv dom) old))))
      update;
    o
end

let layer ?class_ ?update_on_doc_view_update ?mount ?destroy ~above ~update
    ~markers () : Extension.t =
  let o = Jv.obj [||] in
  Jv.set_if_some o "class" (Option.map Jv.of_string class_);
  Jv.Bool.set_if_some o "updateOnDocViewUpdate" update_on_doc_view_update;
  Option.iter
    (fun f ->
      Jv.set o "mount"
        (Jv.callback ~arity:2 (fun (l : Jv.t) (view : Jv.t) ->
             f (Brr.El.of_jv l) view)))
    mount;
  Option.iter
    (fun f ->
      Jv.set o "destroy"
        (Jv.callback ~arity:2 (fun (l : Jv.t) (view : Jv.t) ->
             f (Brr.El.of_jv l) view)))
    destroy;
  Jv.Bool.set o "above" above;
  Jv.set o "update"
    (Jv.callback ~arity:2 (fun (u : Jv.t) (l : Jv.t) ->
         Jv.of_bool (update u (Brr.El.of_jv l))));
  Jv.set o "markers"
    (Jv.callback ~arity:1 (fun (view : Jv.t) ->
         Jv.of_list Fun.id (markers view)));
  Extension.of_jv (Jv.call (Lazy.force pkg) "layer" [| o |])

module RectangleMarker = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let make ~class_ ~left ~top ~width ~height : t =
    let width_jv =
      match width with None -> Jv.null | Some w -> Jv.of_float w
    in
    Jv.new'
      (Lazy.force rectangle_marker_cls)
      [|
        Jv.of_string class_;
        Jv.of_float left;
        Jv.of_float top;
        width_jv;
        Jv.of_float height;
      |]

  let for_range (view : editor_view) ~class_ (range : SelectionRange.t) : t list
      =
    Jv.call
      (Lazy.force rectangle_marker_cls)
      "forRange"
      [| view; Jv.of_string class_; SelectionRange.to_jv range |]
    |> Jv.to_list Fun.id
end
