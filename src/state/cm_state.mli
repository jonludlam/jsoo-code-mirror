(** {{:https://codemirror.net/docs/ref/#state} \@codemirror/state}: the editor
    state, its document and selection, and the extension system of facets,
    fields, effects and transactions. *)

(** Converters between OCaml values and their JavaScript representation. Every
    generic CodeMirror type ([StateField<T>], [RangeSet<T>], ...) is bound as
    ['a t] carrying one of these. *)
module Conv : sig
  type 'a t = { to_jv : 'a -> Jv.t; of_jv : Jv.t -> 'a }

  val jv : Jv.t t
  val int : int t
  val float : float t
  val bool : bool t
  val string : string t
  val jstr : Jstr.t t

  val option : 'a t -> 'a option t
  (** [null] and [undefined] are [None]. *)

  val list : 'a t -> 'a list t
  (** a JavaScript array *)

  val of_module : (module Jv.CONV with type t = 'a) -> 'a t

  val invalid : string -> Jv.t -> 'a
  (** raises [Invalid_argument] naming the module; for [of_jv] that cannot
      decode *)
end

(** Typed JavaScript values, after patricoferris/jsoo-code-mirror#17.

    Every generic type below ([StateField], [StateEffectType], [Range],
    [RangeSet], [RangeSetBuilder], [AnnotationType]) is a JavaScript handle
    carrying the converter for its payload, and shares the signature
    {!Tjv.CONV}. Each keeps its own abstract ['a t], so a [RangeSet] is never
    mistaken for a [StateField]. *)
module Tjv : sig
  type 'a conv = 'a Conv.t = { to_jv : 'a -> Jv.t; of_jv : Jv.t -> 'a }
  (** The same record as {!Conv.t}. *)

  val conv : ('a -> Jv.t) -> (Jv.t -> 'a) -> 'a conv
  (** Make a new conversion value. *)

  module type CONV = sig
    type 'a t

    val to_jv : 'a t -> Jv.t

    val of_jv : 'a conv -> Jv.t -> 'a t
    (** Wraps a value another package made, such as [EditorView.announce] or
        [foldState]; the converter is for its payload. *)

    val conv : 'a t -> 'a conv
    (** The payload's converter. *)

    val any : 'a t -> Jv.t t
    (** Forgets the payload's type. *)

    val conv_of : 'a conv -> 'a t conv
    (** A converter for the container itself, as {!Conv.list} is for lists:
        [RangeSet.conv_of Decoration.conv] is the converter of a field of
        decorations. *)
  end
end

(** Bridging OCaml futures and JavaScript promises.

    Not part of CodeMirror: shared plumbing, here because every package that
    takes an asynchronous source needs it and they all depend on this one. A
    CodeMirror source returning [Promise<T>] is an OCaml function returning
    ['a Fut.t]; these convert the result. *)
module Async : sig
  val promise_of_fut : ('a -> Jv.t) -> 'a Fut.t -> Jv.t
  (** [promise_of_fut encode fut] is the promise a JavaScript caller expects,
      resolving with [encode]'s result. *)

  val fut_of_promise : (Jv.t -> 'a) -> Jv.t -> 'a Fut.t
  (** [fut_of_promise decode p] awaits [p], decoding what it resolves to. Use
      {!Jv.Promise.resolve} first where the JavaScript value may be either a
      promise or a plain result. *)
end

(* Forward declarations, equated below. *)
type editor_state
type transaction
type state_effect
type 'a state_field
type annotation
type ('i, 'o) facet

type 'o facet_reader
(** A facet seen read-only; see {!Facet.reader}. *)

(** {{:https://codemirror.net/docs/ref/#state.Extension} state.Extension} *)
module Extension : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val of_list : t list -> t
  (** CodeMirror's [Extension] includes arrays of extensions. *)

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

(** {{:https://codemirror.net/docs/ref/#state.Line} state.Line} *)
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

  val of_string : string -> t
  (** [Text.of(s.split("\n"))] *)

  val of_lines : string list -> t
  val empty : t
  val to_string : t -> string
  val length : t -> int
  val lines : t -> int

  val line : t -> int -> Line.t
  (** by 1-based number *)

  val line_at : t -> int -> Line.t
  (** by position *)

  val slice_string : ?from:int -> ?to_:int -> ?line_sep:string -> t -> string
  val slice : ?from:int -> ?to_:int -> t -> t
  val replace : t -> from:int -> to_:int -> t -> t
  val append : t -> t -> t
  val eq : t -> t -> bool
  val iter_lines : ?from:int -> ?to_:int -> t -> (string -> unit) -> unit

  val iter : ?forward:bool -> t -> (string -> line_break:bool -> unit) -> unit
  (** [Text.iter]: drives the JavaScript [TextIterator] to completion instead of
      exposing its stateful [next]/[value]/[done] protocol. *)

  val iter_range :
    from:int -> ?to_:int -> t -> (string -> line_break:bool -> unit) -> unit
  (** [Text.iterRange]; see {!iter}. *)
end

(** {{:https://codemirror.net/docs/ref/#state.MapMode} state.MapMode} *)
module MapMode : sig
  type t = Simple | Track_del | Track_before | Track_after
end

(** {{:https://codemirror.net/docs/ref/#state.ChangeDesc} state.ChangeDesc} *)
module ChangeDesc : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val length : t -> int
  val new_length : t -> int
  val empty : t -> bool

  val map_pos : ?assoc:int -> ?mode:MapMode.t -> t -> int -> int option
  (** [None] when [mode] says the position was deleted; with the default mode a
      position is always mapped. *)

  val touches_range :
    t -> from:int -> ?to_:int -> unit -> [ `No | `Touches | `Covers ]
  (** [`Covers] is JavaScript's ["cover"]: the range is inside a single
      replacement, so anything positioned in it is gone rather than moved. *)

  val invert : t -> t
  val compose_desc : t -> t -> t
  val iter_gaps : t -> (from_a:int -> to_a:int -> length:int -> unit) -> unit

  val iter_changed_ranges :
    ?individual:bool ->
    t ->
    (from_a:int -> to_a:int -> from_b:int -> to_b:int -> unit) ->
    unit

  val map_desc : ?before:bool -> t -> t -> t
  val to_json : t -> Jv.t
  val of_json : Jv.t -> t
end

(** What a change asks for: CodeMirror's [ChangeSpec]. A [ChangeSet.t] is also
    one; see {!ChangeSet.to_spec}. *)
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

  val desc : t -> ChangeDesc.t
  (** the [ChangeDesc] view of it; every [ChangeDesc] function applies through
      this *)

  val to_spec : t -> ChangeSpec.t
  val apply : t -> Text.t -> Text.t
  val invert : t -> Text.t -> t
  val compose : t -> t -> t
  val map : ?before:bool -> t -> ChangeDesc.t -> t

  val iter_changes :
    ?individual:bool ->
    t ->
    (from_a:int ->
    to_a:int ->
    from_b:int ->
    to_b:int ->
    inserted:Text.t ->
    unit) ->
    unit

  val empty : int -> t
  val of_ : ?line_sep:string -> ChangeSpec.t -> length:int -> t
  val to_json : t -> Jv.t
  val of_json : Jv.t -> t
end

(** {{:https://codemirror.net/docs/ref/#state.SelectionRange}
     state.SelectionRange} *)
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
  val to_json : t -> Jv.t
  val of_json : Jv.t -> t
end

(** {{:https://codemirror.net/docs/ref/#state.EditorSelection}
     state.EditorSelection} *)
module EditorSelection : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val ranges : t -> SelectionRange.t list
  val main : t -> SelectionRange.t
  val main_index : t -> int
  val single : ?head:int -> int -> t
  val create : ?main_index:int -> SelectionRange.t list -> t

  val cursor :
    ?assoc:int -> ?bidi_level:int -> ?goal_column:int -> int -> SelectionRange.t

  val range :
    ?goal_column:int ->
    ?bidi_level:int ->
    anchor:int ->
    head:int ->
    unit ->
    SelectionRange.t

  val map : ?assoc:int -> t -> ChangeDesc.t -> t
  val eq : t -> t -> bool
  val as_single : t -> t
  val add_range : ?main:bool -> t -> SelectionRange.t -> t
  val replace_range : ?which:int -> t -> SelectionRange.t -> t
  val to_json : t -> Jv.t
  val of_json : Jv.t -> t
end

(* StateEffectType comes first since StateEffect.is/value mention it, and
   StateEffectType.of_ returns [state_effect]. *)

(** {{:https://codemirror.net/docs/ref/#state.StateEffectType}
     state.StateEffectType} *)
module StateEffectType : sig
  type 'a t

  include Tjv.CONV with type 'a t := 'a t

  val define : ?map:('a -> ChangeDesc.t -> 'a option) -> 'a Conv.t -> 'a t
  val of_ : 'a t -> 'a -> state_effect
  val reconfigure : Extension.t t
  val append_config : Extension.t t
end

(** An effect instance.
    {{:https://codemirror.net/docs/ref/#state.StateEffect} state.StateEffect} *)
module StateEffect : sig
  type t = state_effect

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val is : t -> 'a StateEffectType.t -> bool
  val value : t -> 'a StateEffectType.t -> 'a option
  val map : t -> ChangeDesc.t -> t option
  val map_effects : t list -> ChangeDesc.t -> t list
end

(* [dep] used by [Facet.compute]. *)
type dep =
  | Doc
  | Selection
  | Facet_dep : (_, _) facet -> dep
  | Field_dep : _ state_field -> dep

(** {{:https://codemirror.net/docs/ref/#state.Facet} state.Facet} *)
module Facet : sig
  type ('input, 'output) t = ('input, 'output) facet

  val define :
    ?compare:('output -> 'output -> bool) ->
    ?compare_input:('input -> 'input -> bool) ->
    ?static:bool ->
    ?enables:Extension.t ->
    combine:('input list -> 'output) ->
    'input Conv.t ->
    'output Conv.t ->
    ('input, 'output) t

  val define_list :
    ?compare_input:('input -> 'input -> bool) ->
    ?static:bool ->
    ?enables:Extension.t ->
    'input Conv.t ->
    ('input, 'input list) t
  (** CodeMirror's default: the output is the list of inputs. *)

  val of_ : ('i, 'o) t -> 'i -> Extension.t
  val from : ?get:('a -> 'i) -> ('i, 'o) t -> 'a state_field -> Extension.t

  val compute :
    ('i, 'o) t -> deps:dep list -> (editor_state -> 'i) -> Extension.t

  val compute_n :
    ('i, 'o) t -> deps:dep list -> (editor_state -> 'i list) -> Extension.t

  val input_conv : ('i, 'o) t -> 'i Conv.t
  val output_conv : ('i, 'o) t -> 'o Conv.t
  val to_jv : ('i, 'o) t -> Jv.t
  val of_jv : 'i Conv.t -> 'o Conv.t -> Jv.t -> ('i, 'o) t

  val reader : ('i, 'o) t -> 'o facet_reader
  (** A read-only view of the facet, which {!EditorState.facet} also accepts.
      Not an {!Extension.t}: it configures nothing. *)
end

(** {{:https://codemirror.net/docs/ref/#state.StateField} state.StateField} *)
module StateField : sig
  type 'a t = 'a state_field

  include Tjv.CONV with type 'a t := 'a t

  val define :
    ?compare:('a -> 'a -> bool) ->
    ?provide:('a t -> Extension.t) ->
    ?to_json:('a -> editor_state -> Jv.t) ->
    ?from_json:(Jv.t -> editor_state -> 'a) ->
    'a Conv.t ->
    create:(editor_state -> 'a) ->
    update:('a -> transaction -> 'a) ->
    'a t

  val extension : 'a t -> Extension.t
  val init : 'a t -> (editor_state -> 'a) -> Extension.t
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

(** An abstract base class meant to be subclassed in JavaScript (as
    [@codemirror/view]'s [Decoration] does); only the read accessors are bound
    here.
    {{:https://codemirror.net/docs/ref/#state.RangeValue} state.RangeValue} *)
module RangeValue : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val eq : t -> t -> bool
  val start_side : t -> int
  val end_side : t -> int
  val map_mode : t -> MapMode.t
  val point : t -> bool
end

(** {{:https://codemirror.net/docs/ref/#state.Range} state.Range} *)
module Range : sig
  type 'a t

  include Tjv.CONV with type 'a t := 'a t

  val from : 'a t -> int
  val to_ : 'a t -> int
  val value : 'a t -> 'a

  val make : 'a Conv.t -> from:int -> to_:int -> 'a -> 'a t
  (** [value.range(from, to)]: the value must be a CodeMirror [RangeValue] such
      as a [Decoration]. *)
end

(** {{:https://codemirror.net/docs/ref/#state.RangeSet} state.RangeSet} *)
module RangeSet : sig
  type 'a t

  include Tjv.CONV with type 'a t := 'a t

  val empty : 'a Conv.t -> 'a t
  val of_ : ?sort:bool -> 'a Conv.t -> 'a Range.t list -> 'a t
  val size : 'a t -> int

  val update :
    ?add:'a Range.t list ->
    ?sort:bool ->
    ?filter:(from:int -> to_:int -> 'a -> bool) ->
    ?filter_from:int ->
    ?filter_to:int ->
    'a t ->
    'a t

  val map : 'a t -> ChangeDesc.t -> 'a t

  val between :
    ?from:int -> ?to_:int -> 'a t -> (from:int -> to_:int -> 'a -> bool) -> unit
  (** the callback returns [false] to stop *)

  val iter : ?from:int -> 'a t -> ('a Range.t -> unit) -> unit
  (** drives the JavaScript [RangeCursor] to completion. *)

  val eq : ?from:int -> ?to_:int -> 'a t -> 'a t -> bool
  (** JavaScript's static [eq] compares groups of sets; this compares a single
      pair. Join sets with {!join} first to compare groups. *)

  val join : 'a Conv.t -> 'a t list -> 'a t
end

(** {{:https://codemirror.net/docs/ref/#state.RangeSetBuilder}
     state.RangeSetBuilder} *)
module RangeSetBuilder : sig
  type 'a t

  include Tjv.CONV with type 'a t := 'a t

  val make : 'a Conv.t -> unit -> 'a t
  val add : 'a t -> from:int -> to_:int -> 'a -> unit
  val finish : 'a t -> 'a RangeSet.t
end

(** {{:https://codemirror.net/docs/ref/#state.AnnotationType}
     state.AnnotationType} *)
module AnnotationType : sig
  type 'a t

  include Tjv.CONV with type 'a t := 'a t

  val define : 'a Conv.t -> 'a t
  val of_ : 'a t -> 'a -> annotation
end

(** {{:https://codemirror.net/docs/ref/#state.Annotation} state.Annotation} *)
module Annotation : sig
  type t = annotation

  include Jv.CONV with type t := t

  val value : t -> 'a AnnotationType.t -> 'a option
end

(** What a transaction is asked to do.
    {{:https://codemirror.net/docs/ref/#state.TransactionSpec}
     state.TransactionSpec} *)
module TransactionSpec : sig
  type t

  include Jv.CONV with type t := t

  type selection =
    | Cursor of int
    | Anchor_head of { anchor : int; head : int }
    | Selection of EditorSelection.t

  val create :
    ?changes:ChangeSpec.t ->
    ?selection:selection ->
    ?effects:state_effect list ->
    ?annotations:Annotation.t list ->
    ?scroll_into_view:bool ->
    ?filter:bool ->
    ?sequential:bool ->
    ?user_event:string ->
    unit ->
    t
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

(** {{:https://codemirror.net/docs/ref/#state.EditorStateConfig}
     state.EditorStateConfig} *)
module EditorStateConfig : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?doc:string ->
    ?text:Text.t ->
    ?selection:EditorSelection.t ->
    ?extensions:Extension.t ->
    unit ->
    t
  (** [doc] and [text] both set JavaScript's [doc] field, as a string or as a
      [Text.t] respectively; pass at most one. *)
end

(** {{:https://codemirror.net/docs/ref/#state.CharCategory} state.CharCategory}
*)
module CharCategory : sig
  type t = Word | Space | Other
end

(* The record a [EditorState.change_by_range] callback returns for each
   range, matching JavaScript's [{range, changes?, effects?}]. *)
type change_by_range_result = {
  range : SelectionRange.t;
  changes : ChangeSpec.t option;
  effects : state_effect list;
}

(** {{:https://codemirror.net/docs/ref/#state.EditorState} state.EditorState}.
    Where CodeMirror has both a static facet and an instance getter of the same
    name ([tabSize], [lineSeparator], [readOnly]), the getter keeps the name and
    the facet has the [_facet] suffix. *)
module EditorState : sig
  type t = editor_state

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val create : ?config:EditorStateConfig.t -> unit -> t
  val doc : t -> Text.t
  val selection : t -> EditorSelection.t

  val field : t -> 'a StateField.t -> 'a
  (** raises [Invalid_argument] if absent *)

  val field_opt : t -> 'a StateField.t -> 'a option
  val facet : t -> ('i, 'o) Facet.t -> 'o
  val update : t -> TransactionSpec.t list -> Transaction.t
  val replace_selection : t -> string -> TransactionSpec.t

  val change_by_range :
    t ->
    (SelectionRange.t -> change_by_range_result) ->
    ChangeSet.t * EditorSelection.t * state_effect list

  val changes : ?spec:ChangeSpec.t -> t -> ChangeSet.t
  val to_text : t -> string -> Text.t
  val slice_doc : ?from:int -> ?to_:int -> t -> string
  val tab_size : t -> int
  val line_break : t -> string
  val read_only : t -> bool
  val phrase : t -> string -> string

  val language_data_at :
    'a Conv.t -> t -> name:string -> pos:int -> ?side:int -> unit -> 'a list

  val char_categorizer : t -> at:int -> string -> CharCategory.t
  val word_at : t -> int -> SelectionRange.t option
  val to_json : t -> Jv.t
  val from_json : ?config:EditorStateConfig.t -> Jv.t -> t
  val allow_multiple_selections : (bool, bool) Facet.t
  val tab_size_facet : (int, int) Facet.t
  val line_separator_facet : (string, string option) Facet.t
  val read_only_facet : (bool, bool) Facet.t
  val phrases : (Jv.t, Jv.t) Facet.t
  val language_data : (Jv.t, Jv.t) Facet.t
  val change_filter : (transaction -> Jv.t, Jv.t) Facet.t
  val transaction_filter : (transaction -> TransactionSpec.t list, Jv.t) Facet.t

  val transaction_extender :
    (transaction -> TransactionSpec.t option, Jv.t) Facet.t
end

(* Free functions of the package: *)
val count_column : string -> tab_size:int -> ?to_:int -> unit -> int

val find_column :
  string -> col:int -> tab_size:int -> ?strict:bool -> unit -> int

val find_cluster_break :
  ?forward:bool -> ?include_extending:bool -> string -> int -> int

val code_point_at : string -> int -> int
val code_point_size : int -> int
val from_code_point : int -> string

(** Not bound:

    - [combineConfig]: generic over a JavaScript object type with a per-property
      combine function keyed by property name; there is no natural expression of
      that against this binding's explicit-converter style, and OCaml
      [StateField]/[Facet] definitions already give a typed way to merge
      configuration.
    - [RangeSet]'s static, multi-set operations ([RangeSet.iter] over a
      collection of sets, [RangeSet.compare], [RangeSet.spans]): these couple
      several range sets through comparator/iterator objects and are mostly used
      by view-layer rendering code; [@codemirror/view]'s higher-level helpers
      are the more natural place for that.
    - Constructing a [RangeValue] instance: it is an abstract class with no
      public constructor, meant to be subclassed in JavaScript (see
      [@codemirror/view]'s [Decoration] for a concrete, constructible subclass);
      only its read accessors are bound, in the [RangeValue] module above.
    - [EditorState.toJSON]/[fromJSON]'s optional [fields] dictionary for custom
      [StateField] (de)serialization: it is a heterogeneous name-to-field map,
      awkward to express with this binding's typed fields; only the built-in
      doc/selection round-trip is bound. *)
