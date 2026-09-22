# Cm_state: the shape of the design-critical modules

These signatures are fixed; implement them exactly and extend the file
with every other export of `@codemirror/state` (see
`node_modules/@codemirror/state/dist/index.d.ts`) in the same style.
Everything goes in one `cm_state.ml` / `cm_state.mli` pair; modules
that refer to each other use the forward types declared at the top.

```ocaml
(** {{:https://codemirror.net/docs/ref/#state} @codemirror/state}: the
    editor state, its document and selection, and the extension system of
    facets, fields, effects and transactions. *)

(** Converters between OCaml values and their JavaScript representation.
    Every generic CodeMirror type ([StateField<T>], [RangeSet<T>], ...)
    is bound as ['a t] carrying one of these. *)
module Conv : sig
  type 'a t = { to_jv : 'a -> Jv.t; of_jv : Jv.t -> 'a }
  val jv : Jv.t t
  val int : int t
  val float : float t
  val bool : bool t
  val string : string t
  val jstr : Jstr.t t
  val option : 'a t -> 'a option t      (** [null] and [undefined] are [None]. *)
  val list : 'a t -> 'a list t          (** a JavaScript array *)
  val of_module : (module Jv.CONV with type t = 'a) -> 'a t
  val invalid : string -> Jv.t -> 'a    (** raises [Invalid_argument] naming the module; for [of_jv] that cannot decode *)
end

(* Forward declarations, equated below. *)
type editor_state
type transaction
type state_effect
type 'a state_field

(** {{:https://codemirror.net/docs/ref/#state.Extension} state.Extension} *)
module Extension : sig
  type t
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val of_list : t list -> t       (** CodeMirror's [Extension] includes arrays of extensions. *)
  val empty : t
end

(** {{:https://codemirror.net/docs/ref/#state.Prec} state.Prec} *)
module Prec : sig
  val highest : Extension.t -> Extension.t
  val high : Extension.t -> Extension.t
  val default : Extension.t -> Extension.t
  val low : Extension.t -> Extension.t
  val lowest : Extension.t -> Extension.t
end

module Line : sig
  type t
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val from : t -> int
  val to_ : t -> int
  val number : t -> int
  val text : t -> string
  val length : t -> int
end

(** {{:https://codemirror.net/docs/ref/#state.Text} state.Text} *)
module Text : sig
  type t
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val of_string : string -> t             (** [Text.of(s.split("\n"))] *)
  val of_lines : string list -> t
  val empty : t
  val to_string : t -> string
  val length : t -> int
  val lines : t -> int
  val line : t -> int -> Line.t           (** by 1-based number *)
  val line_at : t -> int -> Line.t        (** by position *)
  val slice_string : ?from:int -> ?to_:int -> ?line_sep:string -> t -> string
  val slice : ?from:int -> ?to_:int -> t -> t
  val replace : t -> from:int -> to_:int -> t -> t
  val append : t -> t -> t
  val eq : t -> t -> bool
  val iter_lines : ?from:int -> ?to_:int -> t -> (string -> unit) -> unit
end

(** {{:https://codemirror.net/docs/ref/#state.MapMode} state.MapMode} *)
module MapMode : sig
  type t = Simple | Track_del | Track_before | Track_after
end

module ChangeDesc : sig
  type t
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val length : t -> int
  val new_length : t -> int
  val empty : t -> bool
  val map_pos : ?assoc:int -> ?mode:MapMode.t -> t -> int -> int option
  (** [None] when [mode] says the position was deleted; with the default
      mode a position is always mapped. *)
  val touches_range : t -> from:int -> ?to_:int -> unit -> bool
  val invert : t -> t
  val compose_desc : t -> t -> t
  val iter_gaps : t -> (from_a:int -> to_a:int -> length:int -> unit) -> unit
  val iter_changed_ranges : ?individual:bool -> t -> (from_a:int -> to_a:int -> from_b:int -> to_b:int -> unit) -> unit
end

(** What a change asks for: CodeMirror's [ChangeSpec]. A [ChangeSet.t] is
    also one; see {!ChangeSet.to_spec}. *)
module ChangeSpec : sig
  type t
  include Jv.CONV with type t := t
  val replace : from:int -> ?to_:int -> ?insert:string -> unit -> t
  val insert : at:int -> string -> t
  val delete : from:int -> to_:int -> t
  val of_list : t list -> t
end

(** {{:https://codemirror.net/docs/ref/#state.ChangeSet} state.ChangeSet} *)
module ChangeSet : sig
  type t
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val desc : t -> ChangeDesc.t          (** the [ChangeDesc] view of it; every [ChangeDesc] function applies through this *)
  val to_spec : t -> ChangeSpec.t
  val apply : t -> Text.t -> Text.t
  val invert : t -> Text.t -> t
  val compose : t -> t -> t
  val map : ?before:bool -> t -> ChangeDesc.t -> t
  val iter_changes : ?individual:bool -> t -> (from_a:int -> to_a:int -> from_b:int -> to_b:int -> inserted:Text.t -> unit) -> unit
  val empty : int -> t
  val of_ : ?line_sep:string -> ChangeSpec.t -> length:int -> t
end

(** {{:https://codemirror.net/docs/ref/#state.SelectionRange} state.SelectionRange} *)
module SelectionRange : sig
  type t
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val from : t -> int
  val to_ : t -> int
  val anchor : t -> int
  val head : t -> int
  val empty : t -> bool
  val assoc : t -> int
  val bidi_level : t -> int option
  val goal_column : t -> int option
  val map : ?assoc:int -> t -> ChangeDesc.t -> t
  val extend : t -> from:int -> ?to_:int -> unit -> t
  val eq : ?include_assoc:bool -> t -> t -> bool
end

(** {{:https://codemirror.net/docs/ref/#state.EditorSelection} state.EditorSelection} *)
module EditorSelection : sig
  type t
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val ranges : t -> SelectionRange.t list
  val main : t -> SelectionRange.t
  val main_index : t -> int
  val single : ?head:int -> int -> t
  val create : ?main_index:int -> SelectionRange.t list -> t
  val cursor : ?assoc:int -> ?bidi_level:int -> ?goal_column:int -> int -> SelectionRange.t
  val range : ?goal_column:int -> ?bidi_level:int -> anchor:int -> head:int -> unit -> SelectionRange.t
  val map : ?assoc:int -> t -> ChangeDesc.t -> t
  val eq : t -> t -> bool
  val as_single : t -> t
  val add_range : ?main:bool -> t -> SelectionRange.t -> t
  val replace_range : ?which:int -> t -> SelectionRange.t -> t
end

(** An effect instance. {{:https://codemirror.net/docs/ref/#state.StateEffect} state.StateEffect} *)
module StateEffect : sig
  type t = state_effect
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val is : t -> 'a StateEffectType.t -> bool           (* declared after; see the forward type note *)
  val value : t -> 'a StateEffectType.t -> 'a option   (** [Some] when {!is} *)
  val map : t -> ChangeDesc.t -> t option
end
(* StateEffectType must come first in the file since StateEffect.is/value
   mention it; declare it before StateEffect and have StateEffectType.of_
   return [state_effect]. *)

(** {{:https://codemirror.net/docs/ref/#state.StateEffectType} state.StateEffectType} *)
module StateEffectType : sig
  type 'a t
  val define : ?map:('a -> ChangeDesc.t -> 'a option) -> 'a Conv.t -> 'a t
  val of_ : 'a t -> 'a -> state_effect
  val conv : 'a t -> 'a Conv.t
  val reconfigure : Extension.t t
  val append_config : Extension.t t
end

(** {{:https://codemirror.net/docs/ref/#state.Facet} state.Facet} *)
module Facet : sig
  type ('input, 'output) t
  val define :
    ?compare:('output -> 'output -> bool) -> ?compare_input:('input -> 'input -> bool) ->
    ?static:bool -> ?enables:Extension.t ->
    combine:('input list -> 'output) -> 'input Conv.t -> 'output Conv.t -> ('input, 'output) t
  val define_list : ?compare_input:('input -> 'input -> bool) -> ?static:bool -> ?enables:Extension.t ->
    'input Conv.t -> ('input, 'input list) t
  (** CodeMirror's default: the output is the list of inputs. *)
  val of_ : ('i, 'o) t -> 'i -> Extension.t
  val from : ?get:('a -> 'i) -> ('i, 'o) t -> 'a state_field -> Extension.t
  val compute : ('i, 'o) t -> deps:dep list -> (editor_state -> 'i) -> Extension.t
  val compute_n : ('i, 'o) t -> deps:dep list -> (editor_state -> 'i list) -> Extension.t
  val input_conv : ('i, 'o) t -> 'i Conv.t
  val output_conv : ('i, 'o) t -> 'o Conv.t
  val to_jv : ('i, 'o) t -> Jv.t
  val of_jv : 'i Conv.t -> 'o Conv.t -> Jv.t -> ('i, 'o) t
  val reader : ('i, 'o) t -> Extension.t   (* facet.reader is FacetReader; expose minimally *)
end
(* [dep] is declared before Facet: *)
type dep = Doc | Selection | Facet_dep : (_, _) facet -> dep | Field_dep : _ state_field -> dep
(* where [type ('i,'o) facet] is a forward type equated to Facet.t. *)

(** {{:https://codemirror.net/docs/ref/#state.StateField} state.StateField} *)
module StateField : sig
  type 'a t = 'a state_field
  val define :
    ?compare:('a -> 'a -> bool) -> ?provide:('a t -> Extension.t) -> ?to_json:('a -> Jv.t) -> ?from_json:(Jv.t -> 'a) ->
    'a Conv.t -> create:(editor_state -> 'a) -> update:('a -> transaction -> 'a) -> 'a t
  val extension : 'a t -> Extension.t
  val init : 'a t -> (editor_state -> 'a) -> Extension.t
  val conv : 'a t -> 'a Conv.t
  val to_jv : 'a t -> Jv.t
end

(** {{:https://codemirror.net/docs/ref/#state.Compartment} state.Compartment} *)
module Compartment : sig
  type t
  include Jv.CONV with type t := t
  val make : unit -> t
  val of_ : t -> Extension.t -> Extension.t
  val reconfigure : t -> Extension.t -> state_effect
  val get : t -> editor_state -> Extension.t option
end

(** {{:https://codemirror.net/docs/ref/#state.Range} state.Range} *)
module Range : sig
  type 'a t
  val from : 'a t -> int
  val to_ : 'a t -> int
  val value : 'a t -> 'a
  val make : 'a Conv.t -> from:int -> to_:int -> 'a -> 'a t
  (** [value.range(from, to)]: the value must be a CodeMirror [RangeValue]
      such as a [Decoration]. *)
  val conv : 'a Conv.t -> 'a t Conv.t
end

(** {{:https://codemirror.net/docs/ref/#state.RangeSet} state.RangeSet} *)
module RangeSet : sig
  type 'a t
  val conv : 'a Conv.t -> 'a t Conv.t
  val empty : 'a Conv.t -> 'a t
  val of_ : ?sort:bool -> 'a Conv.t -> 'a Range.t list -> 'a t
  val size : 'a t -> int
  val update : ?add:'a Range.t list -> ?sort:bool -> ?filter:(from:int -> to_:int -> 'a -> bool) -> ?filter_from:int -> ?filter_to:int -> 'a t -> 'a t
  val map : 'a t -> ChangeDesc.t -> 'a t
  val between : ?from:int -> ?to_:int -> 'a t -> (from:int -> to_:int -> 'a -> bool) -> unit
  (** the callback returns [false] to stop *)
  val iter : ?from:int -> 'a t -> ('a Range.t -> unit) -> unit
  val eq : ?from:int -> ?to_:int -> 'a t -> 'a t -> bool
  val join : 'a Conv.t -> 'a t list -> 'a t
end

module RangeSetBuilder : sig
  type 'a t
  val make : 'a Conv.t -> unit -> 'a t
  val add : 'a t -> from:int -> to_:int -> 'a -> unit
  val finish : 'a t -> 'a RangeSet.t
end

module Annotation : sig
  type t
  include Jv.CONV with type t := t
  val value : t -> 'a AnnotationType.t -> 'a option   (* AnnotationType declared first, as with effects *)
end
module AnnotationType : sig
  type 'a t
  val define : 'a Conv.t -> 'a t
  val of_ : 'a t -> 'a -> annotation   (* forward type *)
end

(** What a transaction is asked to do.
    {{:https://codemirror.net/docs/ref/#state.TransactionSpec} state.TransactionSpec} *)
module TransactionSpec : sig
  type t
  include Jv.CONV with type t := t
  type selection = Cursor of int | Anchor_head of { anchor : int; head : int } | Selection of EditorSelection.t
  val create :
    ?changes:ChangeSpec.t -> ?selection:selection -> ?effects:state_effect list -> ?annotations:Annotation.t list ->
    ?scroll_into_view:bool -> ?filter:bool -> ?sequential:bool -> ?user_event:string -> unit -> t
end

(** What the state made of a spec.
    {{:https://codemirror.net/docs/ref/#state.Transaction} state.Transaction} *)
module Transaction : sig
  type t = transaction
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val start_state : t -> editor_state
  val state : t -> editor_state
  val changes : t -> ChangeSet.t
  val selection : t -> EditorSelection.t option
  val effects : t -> state_effect list
  val scroll_into_view : t -> bool
  val new_doc : t -> Text.t
  val new_selection : t -> EditorSelection.t
  val doc_changed : t -> bool
  val reconfigured : t -> bool
  val annotation : t -> 'a AnnotationType.t -> 'a option
  val is_user_event : t -> string -> bool
  val time : int AnnotationType.t
  val user_event : string AnnotationType.t
  val add_to_history : bool AnnotationType.t
  val remote : bool AnnotationType.t
end

(** {{:https://codemirror.net/docs/ref/#state.EditorStateConfig} state.EditorStateConfig} *)
module EditorStateConfig : sig
  type t
  include Jv.CONV with type t := t
  val create : ?doc:string -> ?text:Text.t -> ?selection:EditorSelection.t -> ?extensions:Extension.t -> unit -> t
end

(** {{:https://codemirror.net/docs/ref/#state.EditorState} state.EditorState}.
    Where CodeMirror has both a static facet and an instance getter of the
    same name ([tabSize], [lineSeparator], [readOnly]), the getter keeps
    the name and the facet has the [_facet] suffix. *)
module EditorState : sig
  type t = editor_state
  include Jv.CONV with type t := t
  val conv : t Conv.t
  val create : ?config:EditorStateConfig.t -> unit -> t
  val doc : t -> Text.t
  val selection : t -> EditorSelection.t
  val field : t -> 'a StateField.t -> 'a          (** raises [Invalid_argument] if absent *)
  val field_opt : t -> 'a StateField.t -> 'a option
  val facet : t -> ('i, 'o) Facet.t -> 'o
  val update : t -> TransactionSpec.t list -> Transaction.t
  val replace_selection : t -> string -> TransactionSpec.t
  val changes : ?spec:ChangeSpec.t -> t -> ChangeSet.t
  val to_text : t -> string -> Text.t
  val slice_doc : ?from:int -> ?to_:int -> t -> string
  val tab_size : t -> int
  val line_break : t -> string
  val read_only : t -> bool
  val phrase : t -> string -> string
  val word_at : t -> int -> SelectionRange.t option
  val to_json : t -> Jv.t
  val from_json : ?config:EditorStateConfig.t -> Jv.t -> t
  val allow_multiple_selections : (bool, bool) Facet.t
  val tab_size_facet : (int, int) Facet.t
  val line_separator_facet : (string, string option) Facet.t
  val read_only_facet : (bool, bool) Facet.t
  val phrases : (Jv.t, Jv.t) Facet.t
  val language_data : (Jv.t, Jv.t) Facet.t
  val change_filter : ((transaction -> Jv.t), Jv.t) Facet.t
  val transaction_filter : ((transaction -> TransactionSpec.t list), Jv.t) Facet.t
  val transaction_extender : ((transaction -> TransactionSpec.t option), Jv.t) Facet.t
end

(* Free functions of the package: *)
val combine_config : ... (* skip if awkward *)
val count_column : string -> tab_size:int -> ?to_:int -> unit -> int
val find_column : string -> col:int -> tab_size:int -> ?strict:bool -> unit -> int
val find_cluster_break : ?forward:bool -> ?include_extending:bool -> string -> int -> int
val code_point_at : string -> int -> int
val code_point_size : int -> int
val from_code_point : int -> string
module CharCategory : sig type t = Word | Space | Other end
```

## Questions and friction

Things in the fixed signatures (or their natural extension to the rest of
the package) that turned out awkward, surprising, or worth a second look:

- **`Facet.reader` typed as `Extension.t`.** JavaScript's `facet.reader`
  is a `FacetReader`, a type unrelated to `Extension` that exists only so
  `EditorState.facet`/`Facet.compute` can accept either a `Facet` or a
  reader. Typing it as `Extension.t` compiles only because every bound
  type here is `Jv.t` underneath, so the "conversion" is a silent
  bitcast with no real relationship to what an `Extension` is. It works,
  but a reader passed to `Prec.highest` or `Extension.of_list` would
  silently produce garbage instead of a type error. A `FacetReader.t`
  forward type (like `state_effect`/`annotation`) would have been
  cleaner and not meaningfully harder to wire through `Facet.compute`'s
  `dep` and `EditorState.facet`.
- **Two different shapes for "the generic-with-payload types".**
  `StateField.t`/`Facet.t`/`AnnotationType.t`/`StateEffectType.t`/
  `Range.t`/`RangeSet.t` all need to carry a `Conv.t` alongside the raw
  `Jv.t` handle (since e.g. `Range.value` and `StateField.conv` have no
  way to get a converter from the call site), so they end up as small
  records `{ jv; conv }` rather than `Jv.t` aliases. That's an
  unavoidable consequence of the "carry a converter" convention, but it
  means these types quietly stop being plain `Jv.t` while types like
  `Extension.t`/`Transaction.t` stay `Jv.t` — a reader of the `.mli`
  alone can't tell which is which, only the implementation reveals it.
- **`RangeSet.eq`'s single-pair signature loses information.**
  JavaScript's static `RangeSet.eq` compares *groups* of sets in one
  pass (used by the view layer to diff old vs. new decoration layers
  cheaply); the fixed signature reduces this to comparing exactly one
  set to one set. That is implementable (wrap each side in a
  one-element array before calling), but it means a consumer wanting the
  real multi-set comparison has to reconstruct it themselves via
  `RangeSet.join`, which changes its complexity characteristics (join
  eagerly merges, rather than comparing lazily during iteration).
- **`ChangeDesc.touches_range` losing the `"cover"` case.** JavaScript
  returns `boolean | "cover"`; collapsing that to `bool` (as the fixed
  signature requires) is a real loss of information for a caller who
  specifically wants to know "does one change swallow this range
  entirely", e.g. to decide whether a decoration should be dropped
  outright rather than just re-rendered. A `[ \`No | \`Touches | \`Covers ]`
  return type would have kept this without much extra cost.
- **`?to_json`/`?from_json` on `StateField.define` drop the `state`
  argument JavaScript's `StateFieldSpec` passes.** This was already
  called out as a fixed simplification, but it is worth confirming in
  practice: JSON (de)serialization strategies that need to consult other
  fields of the state they are attached to (a common pattern — e.g.
  resolving IDs against a companion field) simply cannot be expressed
  through this binding and have to fall back to `Jv.t`-level escape
  hatches.
- **The forward-type trick works cleanly for the six types DESIGN.md
  calls out, but doesn't scale to every "module A's function returns
  module B's abstract type where B is defined later" case.** For
  `AnnotationType.t`/`StateEffectType.t`/`Range.t`/`RangeSet.t`, nothing
  *before* their own module needs to name them, so they stay ordinary
  module-local abstract types — no forward declaration needed. That's
  fortunate rather than designed: had `EditorState`'s `field`/`facet`
  (defined much earlier, needed by `Facet`/`StateField`) instead been
  needed by, say, `ChangeDesc`, a much longer prefix of the file would
  have had to move above `EditorState`, or more forward types would have
  been needed. The convention scales to "a handful of central types
  referenced everywhere", not to arbitrary mutual reference.
- **Binding `EditorState.changeByRange` in the fixed style requires an
  ad hoc record type** (`change_by_range_result`, not part of the fixed
  signatures) declared at top level next to the forward types, purely so
  the callback's return shape has a name. It is a fine solution, but it
  is a second, quieter instance of the "declare something before its
  natural home" pattern that the forward-type convention is meant to
  handle explicitly — this one isn't called out anywhere, so a reader
  has to notice it is there for the same reason.
