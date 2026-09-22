module Conv = struct
  type 'a t = { to_jv : 'a -> Jv.t; of_jv : Jv.t -> 'a }

  let jv = { to_jv = Fun.id; of_jv = Fun.id }
  let int = { to_jv = Jv.of_int; of_jv = Jv.to_int }
  let float = { to_jv = Jv.of_float; of_jv = Jv.to_float }
  let bool = { to_jv = Jv.of_bool; of_jv = Jv.to_bool }
  let string = { to_jv = Jv.of_string; of_jv = Jv.to_string }
  let jstr = { to_jv = Jv.of_jstr; of_jv = Jv.to_jstr }

  let option (c : 'a t) : 'a option t =
    {
      to_jv = (function None -> Jv.undefined | Some v -> c.to_jv v);
      of_jv = (fun v -> if Jv.is_none v then None else Some (c.of_jv v));
    }

  let list (c : 'a t) : 'a list t =
    { to_jv = Jv.of_list c.to_jv; of_jv = Jv.to_list c.of_jv }

  let of_module (type a) (module M : Jv.CONV with type t = a) : a t =
    { to_jv = M.to_jv; of_jv = M.of_jv }

  let invalid name (_ : Jv.t) = invalid_arg name
end

(* Forward declarations, equated inside the modules below. *)
type editor_state = Jv.t
type transaction = Jv.t
type state_effect = Jv.t
type 'a state_field = { field_jv : Jv.t; field_conv : 'a Conv.t }
type annotation = Jv.t

type ('i, 'o) facet = {
  facet_jv : Jv.t;
  in_conv : 'i Conv.t;
  out_conv : 'o Conv.t;
}

let pkg = lazy (Jv.get Jv.global "__CM__state")
let annotation_cls = lazy (Jv.get (Lazy.force pkg) "Annotation")
let change_desc_cls = lazy (Jv.get (Lazy.force pkg) "ChangeDesc")
let change_set_cls = lazy (Jv.get (Lazy.force pkg) "ChangeSet")
let compartment_cls = lazy (Jv.get (Lazy.force pkg) "Compartment")
let editor_selection_cls = lazy (Jv.get (Lazy.force pkg) "EditorSelection")
let editor_state_cls = lazy (Jv.get (Lazy.force pkg) "EditorState")
let facet_cls = lazy (Jv.get (Lazy.force pkg) "Facet")
let prec_obj = lazy (Jv.get (Lazy.force pkg) "Prec")
let range_set_cls = lazy (Jv.get (Lazy.force pkg) "RangeSet")
let range_set_builder_cls = lazy (Jv.get (Lazy.force pkg) "RangeSetBuilder")
let selection_range_cls = lazy (Jv.get (Lazy.force pkg) "SelectionRange")
let state_effect_cls = lazy (Jv.get (Lazy.force pkg) "StateEffect")
let state_field_cls = lazy (Jv.get (Lazy.force pkg) "StateField")
let text_cls = lazy (Jv.get (Lazy.force pkg) "Text")
let transaction_cls = lazy (Jv.get (Lazy.force pkg) "Transaction")

(* Small helpers: an absent optional argument becomes [undefined], relying
   on JavaScript's own default parameters. *)
let opt_int = Jv.of_option ~none:Jv.undefined Jv.of_int
let opt_str = Jv.of_option ~none:Jv.undefined Jv.of_string
let opt_bool = Jv.of_option ~none:Jv.undefined Jv.of_bool
let opt_jv = Jv.of_option ~none:Jv.undefined Fun.id

module Extension = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let of_list (l : t list) : t = Jv.of_list Fun.id l
  let empty = of_list []
end

module Prec = struct
  let apply name (e : Extension.t) : Extension.t =
    Jv.call (Lazy.force prec_obj) name [| e |]

  let highest e = apply "highest" e
  let high e = apply "high" e
  let default e = apply "default" e
  let low e = apply "low" e
  let lowest e = apply "lowest" e
end

module Line = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let from t = Jv.Int.get t "from"
  let to_ t = Jv.Int.get t "to"
  let number t = Jv.Int.get t "number"
  let text t = Jv.Jstr.get t "text" |> Jstr.to_string
  let length t = Jv.Int.get t "length"
end

module Text = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let of_lines (lines : string list) : t =
    Jv.call (Lazy.force text_cls) "of" [| Jv.of_list Jv.of_string lines |]

  let of_string s = of_lines (String.split_on_char '\n' s)
  let empty = Jv.get (Lazy.force text_cls) "empty"
  let to_string t = Jv.call t "toString" [||] |> Jv.to_string
  let length t = Jv.Int.get t "length"
  let lines t = Jv.Int.get t "lines"
  let line t n = Jv.call t "line" [| Jv.of_int n |]
  let line_at t pos = Jv.call t "lineAt" [| Jv.of_int pos |]

  let slice_string ?from ?to_ ?line_sep t =
    Jv.call t "sliceString"
      [|
        Jv.of_int (Option.value from ~default:0); opt_int to_; opt_str line_sep;
      |]
    |> Jv.to_string

  let slice ?from ?to_ t =
    Jv.call t "slice"
      [| Jv.of_int (Option.value from ~default:0); opt_int to_ |]

  let replace t ~from ~to_ text =
    Jv.call t "replace" [| Jv.of_int from; Jv.of_int to_; text |]

  let append t other = Jv.call t "append" [| other |]
  let eq t other = Jv.call t "eq" [| other |] |> Jv.to_bool

  let iter_lines ?from ?to_ t f =
    let it = Jv.call t "iterLines" [| opt_int from; opt_int to_ |] in
    let rec loop () =
      let r = Jv.call it "next" [||] in
      if not (Jv.Bool.get r "done") then (
        f (Jv.to_string (Jv.get r "value"));
        loop ())
    in
    loop ()

  let iter ?forward t f =
    let dir = match forward with Some false -> -1 | _ -> 1 in
    let it = Jv.call t "iter" [| Jv.of_int dir |] in
    let rec loop () =
      let r = Jv.call it "next" [||] in
      if not (Jv.Bool.get r "done") then (
        f
          (Jv.to_string (Jv.get r "value"))
          ~line_break:(Jv.Bool.get r "lineBreak");
        loop ())
    in
    loop ()

  let iter_range ~from ?to_ t f =
    let it = Jv.call t "iterRange" [| Jv.of_int from; opt_int to_ |] in
    let rec loop () =
      let r = Jv.call it "next" [||] in
      if not (Jv.Bool.get r "done") then (
        f
          (Jv.to_string (Jv.get r "value"))
          ~line_break:(Jv.Bool.get r "lineBreak");
        loop ())
    in
    loop ()
end

module MapMode = struct
  type t = Simple | Track_del | Track_before | Track_after
end

let map_mode_to_int = function
  | MapMode.Simple -> 0
  | MapMode.Track_del -> 1
  | MapMode.Track_before -> 2
  | MapMode.Track_after -> 3

let map_mode_of_int = function
  | 0 -> MapMode.Simple
  | 1 -> MapMode.Track_del
  | 2 -> MapMode.Track_before
  | 3 -> MapMode.Track_after
  | n -> Conv.invalid "MapMode" (Jv.of_int n)

module ChangeDesc = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let length t = Jv.Int.get t "length"
  let new_length t = Jv.Int.get t "newLength"
  let empty t = Jv.Bool.get t "empty"

  let map_pos ?assoc ?mode t pos =
    let mode_jv =
      match mode with
      | None -> Jv.undefined
      | Some m -> Jv.of_int (map_mode_to_int m)
    in
    let r = Jv.call t "mapPos" [| Jv.of_int pos; opt_int assoc; mode_jv |] in
    if Jv.is_null r then None else Some (Jv.to_int r)

  let touches_range t ~from ?to_ () =
    let r = Jv.call t "touchesRange" [| Jv.of_int from; opt_int to_ |] in
    if Jstr.to_string (Jv.typeof r) = "string" then true else Jv.to_bool r

  let invert t : t = Jv.get t "invertedDesc"
  let compose_desc t other = Jv.call t "composeDesc" [| other |]

  let iter_gaps t f =
    let wrapped (a : Jv.t) (b : Jv.t) (l : Jv.t) =
      f ~from_a:(Jv.to_int a) ~to_a:(Jv.to_int b) ~length:(Jv.to_int l)
    in
    Jv.call t "iterGaps" [| Jv.callback ~arity:3 wrapped |] |> ignore

  let iter_changed_ranges ?individual t f =
    let wrapped (fa : Jv.t) (ta : Jv.t) (fb : Jv.t) (tb : Jv.t) =
      f ~from_a:(Jv.to_int fa) ~to_a:(Jv.to_int ta) ~from_b:(Jv.to_int fb)
        ~to_b:(Jv.to_int tb)
    in
    Jv.call t "iterChangedRanges"
      [| Jv.callback ~arity:4 wrapped; opt_bool individual |]
    |> ignore

  let map_desc ?before t other =
    Jv.call t "mapDesc" [| other; opt_bool before |]

  let to_json t = Jv.call t "toJSON" [||]

  let of_json (j : Jv.t) : t =
    Jv.call (Lazy.force change_desc_cls) "fromJSON" [| j |]
end

module ChangeSpec = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let replace ~from ?to_ ?insert () =
    let o = Jv.obj [||] in
    Jv.Int.set o "from" from;
    Jv.Int.set_if_some o "to" to_;
    Jv.set_if_some o "insert" (Option.map Jv.of_string insert);
    o

  let insert ~at s = replace ~from:at ~insert:s ()
  let delete ~from ~to_ = replace ~from ~to_ ()
  let of_list (l : t list) : t = Jv.of_list Fun.id l
end

module ChangeSet = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let desc t : ChangeDesc.t = Jv.get t "desc"
  let to_spec (t : t) : ChangeSpec.t = t
  let apply t (doc : Text.t) : Text.t = Jv.call t "apply" [| doc |]
  let invert t (doc : Text.t) : t = Jv.call t "invert" [| doc |]
  let compose t other = Jv.call t "compose" [| other |]

  let map ?before t (other : ChangeDesc.t) : t =
    Jv.call t "map" [| other; opt_bool before |]

  let iter_changes ?individual t f =
    let wrapped (fa : Jv.t) (ta : Jv.t) (fb : Jv.t) (tb : Jv.t) (ins : Jv.t) =
      f ~from_a:(Jv.to_int fa) ~to_a:(Jv.to_int ta) ~from_b:(Jv.to_int fb)
        ~to_b:(Jv.to_int tb) ~inserted:ins
    in
    Jv.call t "iterChanges"
      [| Jv.callback ~arity:5 wrapped; opt_bool individual |]
    |> ignore

  let empty (n : int) : t =
    Jv.call (Lazy.force change_set_cls) "empty" [| Jv.of_int n |]

  let of_ ?line_sep (spec : ChangeSpec.t) ~length : t =
    Jv.call
      (Lazy.force change_set_cls)
      "of"
      [| spec; Jv.of_int length; opt_str line_sep |]

  let to_json t = Jv.call t "toJSON" [||]

  let of_json (j : Jv.t) : t =
    Jv.call (Lazy.force change_set_cls) "fromJSON" [| j |]
end

module SelectionRange = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let from t = Jv.Int.get t "from"
  let to_ t = Jv.Int.get t "to"
  let anchor t = Jv.Int.get t "anchor"
  let head t = Jv.Int.get t "head"
  let empty t = Jv.Bool.get t "empty"
  let assoc t = Jv.Int.get t "assoc"
  let bidi_level t = Jv.Int.find t "bidiLevel"
  let goal_column t = Jv.Int.find t "goalColumn"
  let map ?assoc t (cd : ChangeDesc.t) = Jv.call t "map" [| cd; opt_int assoc |]

  let extend t ~from ?to_ () =
    Jv.call t "extend" [| Jv.of_int from; opt_int to_ |]

  let eq ?include_assoc t other =
    Jv.call t "eq" [| other; opt_bool include_assoc |] |> Jv.to_bool

  let to_json t = Jv.call t "toJSON" [||]

  let of_json (j : Jv.t) : t =
    Jv.call (Lazy.force selection_range_cls) "fromJSON" [| j |]
end

module EditorSelection = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let ranges t = Jv.get t "ranges" |> Jv.to_list Fun.id
  let main t : SelectionRange.t = Jv.get t "main"
  let main_index t = Jv.Int.get t "mainIndex"

  let single ?head anchor =
    Jv.call
      (Lazy.force editor_selection_cls)
      "single"
      [| Jv.of_int anchor; opt_int head |]

  let create ?main_index (ranges : SelectionRange.t list) =
    Jv.call
      (Lazy.force editor_selection_cls)
      "create"
      [| Jv.of_list Fun.id ranges; opt_int main_index |]

  let cursor ?assoc ?bidi_level ?goal_column pos =
    Jv.call
      (Lazy.force editor_selection_cls)
      "cursor"
      [|
        Jv.of_int pos; opt_int assoc; opt_int bidi_level; opt_int goal_column;
      |]

  let range ?goal_column ?bidi_level ~anchor ~head () =
    Jv.call
      (Lazy.force editor_selection_cls)
      "range"
      [|
        Jv.of_int anchor;
        Jv.of_int head;
        opt_int goal_column;
        opt_int bidi_level;
      |]

  let map ?assoc t (cd : ChangeDesc.t) = Jv.call t "map" [| cd; opt_int assoc |]
  let eq t other = Jv.call t "eq" [| other |] |> Jv.to_bool
  let as_single t = Jv.call t "asSingle" [||]

  let add_range ?main t (r : SelectionRange.t) =
    Jv.call t "addRange" [| r; opt_bool main |]

  let replace_range ?which t (r : SelectionRange.t) =
    Jv.call t "replaceRange" [| r; opt_int which |]

  let to_json t = Jv.call t "toJSON" [||]

  let of_json (j : Jv.t) : t =
    Jv.call (Lazy.force editor_selection_cls) "fromJSON" [| j |]
end

(* StateEffectType comes first since StateEffect.is/value mention it; both
   [define] and the [reconfigure]/[appendConfig] constants live on
   JavaScript's [StateEffect] class, not on a separate constructor. *)
module StateEffectType = struct
  type 'a t = { se_jv : Jv.t; se_conv : 'a Conv.t }

  let define (type a) ?map (conv : a Conv.t) : a t =
    let o = Jv.obj [||] in
    Option.iter
      (fun f ->
        let wrapped (v : Jv.t) (cd : Jv.t) =
          match f (conv.of_jv v) cd with
          | Some v' -> conv.to_jv v'
          | None -> Jv.undefined
        in
        Jv.set o "map" (Jv.callback ~arity:2 wrapped))
      map;
    let jv = Jv.call (Lazy.force state_effect_cls) "define" [| o |] in
    { se_jv = jv; se_conv = conv }

  let of_ (t : 'a t) (v : 'a) : state_effect =
    Jv.call t.se_jv "of" [| t.se_conv.to_jv v |]

  let conv (t : 'a t) = t.se_conv

  let reconfigure : Extension.t t =
    {
      se_jv = Jv.get (Lazy.force state_effect_cls) "reconfigure";
      se_conv = Extension.conv;
    }

  let append_config : Extension.t t =
    {
      se_jv = Jv.get (Lazy.force state_effect_cls) "appendConfig";
      se_conv = Extension.conv;
    }
end

module StateEffect = struct
  type t = state_effect

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let is (e : t) (ty : 'a StateEffectType.t) : bool =
    Jv.call e "is" [| ty.se_jv |] |> Jv.to_bool

  let value (e : t) (ty : 'a StateEffectType.t) : 'a option =
    if is e ty then Some (ty.se_conv.of_jv (Jv.get e "value")) else None

  let map (e : t) (cd : ChangeDesc.t) : t option =
    let r = Jv.call e "map" [| cd |] in
    if Jv.is_undefined r then None else Some r

  let map_effects (effs : t list) (cd : ChangeDesc.t) : t list =
    Jv.call
      (Lazy.force state_effect_cls)
      "mapEffects"
      [| Jv.of_list Fun.id effs; cd |]
    |> Jv.to_list Fun.id
end

type dep =
  | Doc
  | Selection
  | Facet_dep : (_, _) facet -> dep
  | Field_dep : _ state_field -> dep

module Facet = struct
  type ('input, 'output) t = ('input, 'output) facet

  let define (type i o) ?compare ?compare_input ?static ?enables ~combine
      (ic : i Conv.t) (oc : o Conv.t) : (i, o) t =
    let combine_wrapped (arr : Jv.t) =
      oc.to_jv (combine (Jv.to_list ic.of_jv arr))
    in
    let o_obj = Jv.obj [||] in
    Jv.set o_obj "combine" (Jv.callback ~arity:1 combine_wrapped);
    Option.iter
      (fun f ->
        let wrapped (a : Jv.t) (b : Jv.t) =
          Jv.of_bool (f (oc.of_jv a) (oc.of_jv b))
        in
        Jv.set o_obj "compare" (Jv.callback ~arity:2 wrapped))
      compare;
    Option.iter
      (fun f ->
        let wrapped (a : Jv.t) (b : Jv.t) =
          Jv.of_bool (f (ic.of_jv a) (ic.of_jv b))
        in
        Jv.set o_obj "compareInput" (Jv.callback ~arity:2 wrapped))
      compare_input;
    Jv.Bool.set_if_some o_obj "static" static;
    Option.iter (fun e -> Jv.set o_obj "enables" (Extension.to_jv e)) enables;
    let jv = Jv.call (Lazy.force facet_cls) "define" [| o_obj |] in
    { facet_jv = jv; in_conv = ic; out_conv = oc }

  let define_list (type i) ?compare_input ?static ?enables (ic : i Conv.t) :
      (i, i list) t =
    let o_obj = Jv.obj [||] in
    Option.iter
      (fun f ->
        let wrapped (a : Jv.t) (b : Jv.t) =
          Jv.of_bool (f (ic.of_jv a) (ic.of_jv b))
        in
        Jv.set o_obj "compareInput" (Jv.callback ~arity:2 wrapped))
      compare_input;
    Jv.Bool.set_if_some o_obj "static" static;
    Option.iter (fun e -> Jv.set o_obj "enables" (Extension.to_jv e)) enables;
    let jv = Jv.call (Lazy.force facet_cls) "define" [| o_obj |] in
    { facet_jv = jv; in_conv = ic; out_conv = Conv.list ic }

  let of_ (f : ('i, 'o) t) (v : 'i) : Extension.t =
    Jv.call f.facet_jv "of" [| f.in_conv.to_jv v |]

  let from (type a) ?get (f : ('i, 'o) t) (field : a state_field) : Extension.t
      =
    match get with
    | None -> Jv.call f.facet_jv "from" [| field.field_jv |]
    | Some g ->
        let wrapped (v : Jv.t) =
          f.in_conv.to_jv (g (field.field_conv.of_jv v))
        in
        Jv.call f.facet_jv "from"
          [| field.field_jv; Jv.callback ~arity:1 wrapped |]

  let dep_to_jv = function
    | Doc -> Jv.of_string "doc"
    | Selection -> Jv.of_string "selection"
    | Facet_dep fd -> fd.facet_jv
    | Field_dep sf -> sf.field_jv

  let compute (f : ('i, 'o) t) ~deps (get : editor_state -> 'i) : Extension.t =
    let wrapped (st : Jv.t) = f.in_conv.to_jv (get st) in
    Jv.call f.facet_jv "compute"
      [| Jv.of_list dep_to_jv deps; Jv.callback ~arity:1 wrapped |]

  let compute_n (f : ('i, 'o) t) ~deps (get : editor_state -> 'i list) :
      Extension.t =
    let wrapped (st : Jv.t) = Jv.of_list f.in_conv.to_jv (get st) in
    Jv.call f.facet_jv "computeN"
      [| Jv.of_list dep_to_jv deps; Jv.callback ~arity:1 wrapped |]

  let input_conv (f : ('i, 'o) t) = f.in_conv
  let output_conv (f : ('i, 'o) t) = f.out_conv
  let to_jv (f : ('i, 'o) t) = f.facet_jv

  let of_jv ic oc jv : ('i, 'o) t =
    { facet_jv = jv; in_conv = ic; out_conv = oc }

  let reader (f : ('i, 'o) t) : Extension.t = Jv.get f.facet_jv "reader"
end

module StateField = struct
  type 'a t = 'a state_field

  let define (type a) ?compare ?provide ?to_json ?from_json (conv : a Conv.t)
      ~create ~update : a t =
    let create_wrapper (st : Jv.t) = conv.to_jv (create st) in
    let update_wrapper (v : Jv.t) (tr : Jv.t) =
      conv.to_jv (update (conv.of_jv v) tr)
    in
    let o = Jv.obj [||] in
    Jv.set o "create" (Jv.callback ~arity:1 create_wrapper);
    Jv.set o "update" (Jv.callback ~arity:2 update_wrapper);
    Option.iter
      (fun f ->
        let wrapped (a : Jv.t) (b : Jv.t) =
          Jv.of_bool (f (conv.of_jv a) (conv.of_jv b))
        in
        Jv.set o "compare" (Jv.callback ~arity:2 wrapped))
      compare;
    Option.iter
      (fun f ->
        let wrapped (raw : Jv.t) =
          Extension.to_jv (f { field_jv = raw; field_conv = conv })
        in
        Jv.set o "provide" (Jv.callback ~arity:1 wrapped))
      provide;
    Option.iter
      (fun f ->
        let wrapped (v : Jv.t) (_st : Jv.t) = f (conv.of_jv v) in
        Jv.set o "toJSON" (Jv.callback ~arity:2 wrapped))
      to_json;
    Option.iter
      (fun f ->
        let wrapped (j : Jv.t) (_st : Jv.t) = conv.to_jv (f j) in
        Jv.set o "fromJSON" (Jv.callback ~arity:2 wrapped))
      from_json;
    let field_jv = Jv.call (Lazy.force state_field_cls) "define" [| o |] in
    { field_jv; field_conv = conv }

  let extension (f : 'a t) : Extension.t = Jv.get f.field_jv "extension"

  let init (f : 'a t) (init : editor_state -> 'a) : Extension.t =
    let wrapped (st : Jv.t) = f.field_conv.to_jv (init st) in
    Jv.call f.field_jv "init" [| Jv.callback ~arity:1 wrapped |]

  let conv (f : 'a t) = f.field_conv
  let to_jv (f : 'a t) = f.field_jv
end

module Compartment = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let make () = Jv.new' (Lazy.force compartment_cls) [||]
  let of_ (t : t) (e : Extension.t) : Extension.t = Jv.call t "of" [| e |]

  let reconfigure (t : t) (e : Extension.t) : state_effect =
    Jv.call t "reconfigure" [| e |]

  let get (t : t) (st : editor_state) : Extension.t option =
    let r = Jv.call t "get" [| st |] in
    if Jv.is_undefined r then None else Some r
end

module RangeValue = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let eq (a : t) (b : t) = Jv.call a "eq" [| b |] |> Jv.to_bool
  let start_side t = Jv.Int.get t "startSide"
  let end_side t = Jv.Int.get t "endSide"
  let map_mode t = map_mode_of_int (Jv.Int.get t "mapMode")
  let point t = Jv.Bool.get t "point"
end

module Range = struct
  type 'a t = { rg_jv : Jv.t; rg_conv : 'a Conv.t }

  let from (r : 'a t) = Jv.Int.get r.rg_jv "from"
  let to_ (r : 'a t) = Jv.Int.get r.rg_jv "to"
  let value (r : 'a t) = r.rg_conv.of_jv (Jv.get r.rg_jv "value")

  let make (type a) (c : a Conv.t) ~from ~to_ (v : a) : a t =
    {
      rg_jv = Jv.call (c.to_jv v) "range" [| Jv.of_int from; Jv.of_int to_ |];
      rg_conv = c;
    }

  let conv (type a) (c : a Conv.t) : a t Conv.t =
    {
      Conv.to_jv = (fun (r : a t) -> r.rg_jv);
      of_jv = (fun jv -> { rg_jv = jv; rg_conv = c });
    }
end

module RangeSet = struct
  type 'a t = { rs_jv : Jv.t; rs_conv : 'a Conv.t }

  let conv (type a) (c : a Conv.t) : a t Conv.t =
    {
      Conv.to_jv = (fun (t : a t) -> t.rs_jv);
      of_jv = (fun jv -> { rs_jv = jv; rs_conv = c });
    }

  let empty (type a) (c : a Conv.t) : a t =
    { rs_jv = Jv.get (Lazy.force range_set_cls) "empty"; rs_conv = c }

  let of_ (type a) ?sort (c : a Conv.t) (ranges : a Range.t list) : a t =
    let arr = Jv.of_list (fun (r : a Range.t) -> r.rg_jv) ranges in
    {
      rs_jv = Jv.call (Lazy.force range_set_cls) "of" [| arr; opt_bool sort |];
      rs_conv = c;
    }

  let size (t : 'a t) = Jv.Int.get t.rs_jv "size"

  let update (type a) ?add ?sort ?filter ?filter_from ?filter_to (t : a t) : a t
      =
    let o = Jv.obj [||] in
    (match add with
    | None -> ()
    | Some rs -> Jv.set o "add" (Jv.of_list (fun (r : a Range.t) -> r.rg_jv) rs));
    Jv.Bool.set_if_some o "sort" sort;
    Option.iter
      (fun f ->
        let wrapped (from : Jv.t) (to_ : Jv.t) (v : Jv.t) =
          Jv.of_bool
            (f ~from:(Jv.to_int from) ~to_:(Jv.to_int to_) (t.rs_conv.of_jv v))
        in
        Jv.set o "filter" (Jv.callback ~arity:3 wrapped))
      filter;
    Jv.Int.set_if_some o "filterFrom" filter_from;
    Jv.Int.set_if_some o "filterTo" filter_to;
    { t with rs_jv = Jv.call t.rs_jv "update" [| o |] }

  let map (t : 'a t) (cd : ChangeDesc.t) : 'a t =
    { t with rs_jv = Jv.call t.rs_jv "map" [| cd |] }

  let between ?from ?to_ (t : 'a t) f =
    let from = Option.value from ~default:0 in
    let to_ = Option.value to_ ~default:1_000_000_000 in
    let wrapped (fa : Jv.t) (ta : Jv.t) (v : Jv.t) =
      if f ~from:(Jv.to_int fa) ~to_:(Jv.to_int ta) (t.rs_conv.of_jv v) then
        Jv.undefined
      else Jv.false'
    in
    Jv.call t.rs_jv "between"
      [| Jv.of_int from; Jv.of_int to_; Jv.callback ~arity:3 wrapped |]
    |> ignore

  let iter ?from (t : 'a t) (f : 'a Range.t -> unit) : unit =
    let cur = Jv.call t.rs_jv "iter" [| opt_int from |] in
    let rec loop () =
      let v = Jv.get cur "value" in
      if not (Jv.is_null v) then (
        let snapshot =
          Jv.obj
            [|
              ("from", Jv.get cur "from"); ("to", Jv.get cur "to"); ("value", v);
            |]
        in
        f { Range.rg_jv = snapshot; rg_conv = t.rs_conv };
        Jv.call cur "next" [||] |> ignore;
        loop ())
    in
    loop ()

  let eq ?from ?to_ (a : 'a t) (b : 'a t) : bool =
    Jv.call (Lazy.force range_set_cls) "eq"
      [|
        Jv.of_list Fun.id [ a.rs_jv ];
        Jv.of_list Fun.id [ b.rs_jv ];
        opt_int from;
        opt_int to_;
      |]
    |> Jv.to_bool

  let join (type a) (c : a Conv.t) (sets : a t list) : a t =
    let arr = Jv.of_list (fun (s : a t) -> s.rs_jv) sets in
    { rs_jv = Jv.call (Lazy.force range_set_cls) "join" [| arr |]; rs_conv = c }
end

module RangeSetBuilder = struct
  type 'a t = { rb_jv : Jv.t; rb_conv : 'a Conv.t }

  let make (type a) (c : a Conv.t) () : a t =
    { rb_jv = Jv.new' (Lazy.force range_set_builder_cls) [||]; rb_conv = c }

  let add (t : 'a t) ~from ~to_ (v : 'a) =
    Jv.call t.rb_jv "add" [| Jv.of_int from; Jv.of_int to_; t.rb_conv.to_jv v |]
    |> ignore

  let finish (t : 'a t) : 'a RangeSet.t =
    RangeSet.{ rs_jv = Jv.call t.rb_jv "finish" [||]; rs_conv = t.rb_conv }
end

module AnnotationType = struct
  type 'a t = { at_jv : Jv.t; at_conv : 'a Conv.t }

  let define (type a) (conv : a Conv.t) : a t =
    {
      at_jv = Jv.call (Lazy.force annotation_cls) "define" [||];
      at_conv = conv;
    }

  let of_ (t : 'a t) (v : 'a) : annotation =
    Jv.call t.at_jv "of" [| t.at_conv.to_jv v |]
end

module Annotation = struct
  type t = annotation

  include (Jv.Id : Jv.CONV with type t := t)

  let value (ann : t) (ty : 'a AnnotationType.t) : 'a option =
    if Jv.strict_equal (Jv.get ann "type") ty.at_jv then
      Some (ty.at_conv.of_jv (Jv.get ann "value"))
    else None
end

module TransactionSpec = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  type selection =
    | Cursor of int
    | Anchor_head of { anchor : int; head : int }
    | Selection of EditorSelection.t

  let selection_to_jv = function
    | Cursor n -> Jv.obj [| ("anchor", Jv.of_int n) |]
    | Anchor_head { anchor; head } ->
        Jv.obj [| ("anchor", Jv.of_int anchor); ("head", Jv.of_int head) |]
    | Selection s -> s

  let create ?changes ?selection ?effects ?annotations ?scroll_into_view ?filter
      ?sequential ?user_event () =
    let o = Jv.obj [||] in
    Jv.set_if_some o "changes" changes;
    Jv.set_if_some o "selection" (Option.map selection_to_jv selection);
    (match effects with
    | None -> ()
    | Some l -> Jv.set o "effects" (Jv.of_list Fun.id l));
    (match annotations with
    | None -> ()
    | Some l -> Jv.set o "annotations" (Jv.of_list Fun.id l));
    Jv.Bool.set_if_some o "scrollIntoView" scroll_into_view;
    Jv.Bool.set_if_some o "filter" filter;
    Jv.Bool.set_if_some o "sequential" sequential;
    Jv.set_if_some o "userEvent" (Option.map Jv.of_string user_event);
    o
end

module Transaction = struct
  type t = transaction

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let start_state t : editor_state = Jv.get t "startState"
  let state t : editor_state = Jv.get t "state"
  let changes t : ChangeSet.t = Jv.get t "changes"

  let selection t : EditorSelection.t option =
    let s = Jv.get t "selection" in
    if Jv.is_undefined s then None else Some s

  let effects t : state_effect list = Jv.get t "effects" |> Jv.to_list Fun.id
  let scroll_into_view t = Jv.Bool.get t "scrollIntoView"
  let new_doc t : Text.t = Jv.get t "newDoc"
  let new_selection t : EditorSelection.t = Jv.get t "newSelection"
  let doc_changed t = Jv.Bool.get t "docChanged"
  let reconfigured t = Jv.Bool.get t "reconfigured"

  let annotation (t : t) (ty : 'a AnnotationType.t) : 'a option =
    let r = Jv.call t "annotation" [| ty.at_jv |] in
    if Jv.is_undefined r then None else Some (ty.at_conv.of_jv r)

  let is_user_event t ev =
    Jv.call t "isUserEvent" [| Jv.of_string ev |] |> Jv.to_bool

  let time : int AnnotationType.t =
    AnnotationType.
      { at_jv = Jv.get (Lazy.force transaction_cls) "time"; at_conv = Conv.int }

  let user_event : string AnnotationType.t =
    AnnotationType.
      {
        at_jv = Jv.get (Lazy.force transaction_cls) "userEvent";
        at_conv = Conv.string;
      }

  let add_to_history : bool AnnotationType.t =
    AnnotationType.
      {
        at_jv = Jv.get (Lazy.force transaction_cls) "addToHistory";
        at_conv = Conv.bool;
      }

  let remote : bool AnnotationType.t =
    AnnotationType.
      {
        at_jv = Jv.get (Lazy.force transaction_cls) "remote";
        at_conv = Conv.bool;
      }
end

module EditorStateConfig = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?doc ?text ?selection ?extensions () =
    let o = Jv.obj [||] in
    (match text with
    | Some tx -> Jv.set o "doc" tx
    | None -> Jv.set_if_some o "doc" (Option.map Jv.of_string doc));
    Jv.set_if_some o "selection" selection;
    Jv.set_if_some o "extensions" extensions;
    o
end

module CharCategory = struct
  type t = Word | Space | Other
end

let char_category_of_int = function
  | 0 -> CharCategory.Word
  | 1 -> CharCategory.Space
  | 2 -> CharCategory.Other
  | n -> Conv.invalid "CharCategory" (Jv.of_int n)

type change_by_range_result = {
  range : SelectionRange.t;
  changes : ChangeSpec.t option;
  effects : state_effect list;
}

module EditorState = struct
  type t = editor_state

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ?config () =
    Jv.call (Lazy.force editor_state_cls) "create" [| opt_jv config |]

  let doc t : Text.t = Jv.get t "doc"
  let selection t : EditorSelection.t = Jv.get t "selection"

  let field (t : t) (f : 'a state_field) : 'a =
    let v = Jv.call t "field" [| f.field_jv; Jv.false' |] in
    if Jv.is_undefined v then Conv.invalid "EditorState.field" t
    else f.field_conv.of_jv v

  let field_opt (t : t) (f : 'a state_field) : 'a option =
    let v = Jv.call t "field" [| f.field_jv; Jv.false' |] in
    if Jv.is_undefined v then None else Some (f.field_conv.of_jv v)

  let facet (t : t) (f : ('i, 'o) facet) : 'o =
    Jv.call t "facet" [| f.facet_jv |] |> f.out_conv.of_jv

  let update (t : t) (specs : TransactionSpec.t list) : Transaction.t =
    Jv.call t "update" (Array.of_list specs)

  let replace_selection t s : TransactionSpec.t =
    Jv.call t "replaceSelection" [| Jv.of_string s |]

  let change_by_range (t : t) (f : SelectionRange.t -> change_by_range_result) =
    let wrapped (r : Jv.t) =
      let res = f r in
      let o = Jv.obj [||] in
      Jv.set o "range" res.range;
      Jv.set_if_some o "changes" res.changes;
      (match res.effects with
      | [] -> ()
      | l -> Jv.set o "effects" (Jv.of_list Fun.id l));
      o
    in
    let r = Jv.call t "changeByRange" [| Jv.callback ~arity:1 wrapped |] in
    ( Jv.get r "changes",
      Jv.get r "selection",
      Jv.get r "effects" |> Jv.to_list Fun.id )

  let changes ?spec (t : t) : ChangeSet.t =
    Jv.call t "changes" [| opt_jv spec |]

  let to_text t s : Text.t = Jv.call t "toText" [| Jv.of_string s |]

  let slice_doc ?from ?to_ t =
    Jv.call t "sliceDoc" [| opt_int from; opt_int to_ |] |> Jv.to_string

  let tab_size t = Jv.Int.get t "tabSize"
  let line_break t = Jv.Jstr.get t "lineBreak" |> Jstr.to_string
  let read_only t = Jv.Bool.get t "readOnly"
  let phrase t s = Jv.call t "phrase" [| Jv.of_string s |] |> Jv.to_string

  let language_data_at (type a) (c : a Conv.t) (t : t) ~name ~pos ?side () :
      a list =
    Jv.call t "languageDataAt"
      [| Jv.of_string name; Jv.of_int pos; opt_int side |]
    |> Jv.to_list c.of_jv

  let char_categorizer t ~at s =
    let f = Jv.call t "charCategorizer" [| Jv.of_int at |] in
    char_category_of_int (Jv.to_int (Jv.apply f [| Jv.of_string s |]))

  let word_at t pos : SelectionRange.t option =
    let r = Jv.call t "wordAt" [| Jv.of_int pos |] in
    if Jv.is_null r then None else Some r

  let to_json t = Jv.call t "toJSON" [||]

  let from_json ?config (j : Jv.t) : t =
    Jv.call (Lazy.force editor_state_cls) "fromJSON" [| j; opt_jv config |]

  let allow_multiple_selections =
    Facet.of_jv Conv.bool Conv.bool
      (Jv.get (Lazy.force editor_state_cls) "allowMultipleSelections")

  let tab_size_facet =
    Facet.of_jv Conv.int Conv.int
      (Jv.get (Lazy.force editor_state_cls) "tabSize")

  let line_separator_facet =
    Facet.of_jv Conv.string (Conv.option Conv.string)
      (Jv.get (Lazy.force editor_state_cls) "lineSeparator")

  let read_only_facet =
    Facet.of_jv Conv.bool Conv.bool
      (Jv.get (Lazy.force editor_state_cls) "readOnly")

  let phrases =
    Facet.of_jv Conv.jv Conv.jv (Jv.get (Lazy.force editor_state_cls) "phrases")

  let language_data =
    Facet.of_jv Conv.jv Conv.jv
      (Jv.get (Lazy.force editor_state_cls) "languageData")

  let transaction_fn_conv : (transaction -> Jv.t) Conv.t =
    {
      Conv.to_jv = (fun f -> Jv.callback ~arity:1 (fun (tr : Jv.t) -> f tr));
      of_jv = (fun jv (tr : transaction) -> Jv.apply jv [| tr |]);
    }

  let change_filter =
    Facet.of_jv transaction_fn_conv Conv.jv
      (Jv.get (Lazy.force editor_state_cls) "changeFilter")

  let transaction_filter_conv : (transaction -> TransactionSpec.t list) Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          Jv.callback ~arity:1 (fun (tr : Jv.t) -> Jv.of_list Fun.id (f tr)));
      of_jv =
        (fun jv (tr : transaction) ->
          let r = Jv.apply jv [| tr |] in
          if Jv.is_array r then Jv.to_list Fun.id r else [ r ]);
    }

  let transaction_filter =
    Facet.of_jv transaction_filter_conv Conv.jv
      (Jv.get (Lazy.force editor_state_cls) "transactionFilter")

  let transaction_extender_conv :
      (transaction -> TransactionSpec.t option) Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          Jv.callback ~arity:1 (fun (tr : Jv.t) ->
              match f tr with Some s -> s | None -> Jv.null));
      of_jv =
        (fun jv (tr : transaction) ->
          let r = Jv.apply jv [| tr |] in
          if Jv.is_null r then None else Some r);
    }

  let transaction_extender =
    Facet.of_jv transaction_extender_conv Conv.jv
      (Jv.get (Lazy.force editor_state_cls) "transactionExtender")
end

let count_column s ~tab_size ?to_ () =
  Jv.call (Lazy.force pkg) "countColumn"
    [| Jv.of_string s; Jv.of_int tab_size; opt_int to_ |]
  |> Jv.to_int

let find_column s ~col ~tab_size ?strict () =
  Jv.call (Lazy.force pkg) "findColumn"
    [| Jv.of_string s; Jv.of_int col; Jv.of_int tab_size; opt_bool strict |]
  |> Jv.to_int

let find_cluster_break ?forward ?include_extending s pos =
  Jv.call (Lazy.force pkg) "findClusterBreak"
    [|
      Jv.of_string s;
      Jv.of_int pos;
      opt_bool forward;
      opt_bool include_extending;
    |]
  |> Jv.to_int

let code_point_at s pos =
  Jv.call (Lazy.force pkg) "codePointAt" [| Jv.of_string s; Jv.of_int pos |]
  |> Jv.to_int

let code_point_size code =
  Jv.call (Lazy.force pkg) "codePointSize" [| Jv.of_int code |] |> Jv.to_int

let from_code_point code =
  Jv.call (Lazy.force pkg) "fromCodePoint" [| Jv.of_int code |] |> Jv.to_string
