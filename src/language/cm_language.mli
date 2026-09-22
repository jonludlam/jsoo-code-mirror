(** {{:https://codemirror.net/docs/ref/#language} \@codemirror/language}: the
    [Language]/[LRLanguage]/[StreamLanguage] classes, syntax highlighting,
    indentation and code folding, plus the [\@lezer/common], [\@lezer/highlight]
    and [\@lezer/lr] surface this package returns or takes ([Tree],
    [SyntaxNode], [NodeType], [Tag], [LRParser]). Depends on [Cm_state] (opened
    below) and [Cm_view] (referenced qualified). *)

open Cm_state

(* Forward declarations, equated inside the modules below. See Cm_state's
   cross-reference convention: a module needing a type declared later in
   this file uses the forward abstract type instead. *)
type language
type tree
type syntax_node
type node_type
type indent_context

(** {{:https://lezer.codemirror.net/docs/ref/#common.NodeProp} common.NodeProp}:
    kept minimal, as a handle to the library's own predefined instances plus
    this package's [languageDataProp]/[sublanguageProp]/[foldNodeProp]/
    [indentNodeProp]/[bracketMatchingHandle]. Each instance's payload type is
    fixed by which value below it is; nothing here enforces it. Defining new
    props ([NodeProp.define]/[.add]) is not bound; see "Not bound" at the bottom
    of this file. *)
module NodeProp : sig
  type t = Jv.t

  val closed_by : t
  val opened_by : t
  val group : t
  val isolate : t
  val context_hash : t
  val look_ahead : t
  val mounted : t
  val language_data : t
  val sublanguage : t
  val fold : t
  val indent : t
  val bracket_matching_handle : t
end

(** {{:https://lezer.codemirror.net/docs/ref/#common.NodeType} common.NodeType}
*)
module NodeType : sig
  type t = node_type

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val name : t -> string
  val id : t -> int
  val is_top : t -> bool
  val is_skipped : t -> bool
  val is_error : t -> bool
  val is_anonymous : t -> bool
  val is : t -> string -> bool
  val none : t

  val prop : t -> NodeProp.t -> Jv.t option
  (** the raw prop value; decode per the prop's documented shape, or use the
      typed convenience readers below for the common lezer statics. *)

  val closed_by_names : t -> string list
  (** {!NodeProp.closed_by}; [[]] when absent. *)

  val opened_by_names : t -> string list
  val group_names : t -> string list
  val is_isolate : t -> [ `Rtl | `Ltr | `Auto ] option
end

(** {{:https://lezer.codemirror.net/docs/ref/#common.Tree} common.Tree}. Node
    data ([children]/[positions]), [Tree.build] and [TreeBuffer] are not bound;
    see "Not bound". *)
module Tree : sig
  type t = tree

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val type_ : t -> node_type
  val length : t -> int
  val top_node : t -> syntax_node

  val resolve : ?side:int -> t -> int -> syntax_node
  (** At a position between two tokens this returns the node that ends there,
      which for position 0 is the whole document. Pass a position inside the
      token, or a [side], to descend into it. *)

  val resolve_inner : ?side:int -> t -> int -> syntax_node
  val prop : t -> NodeProp.t -> Jv.t option

  val iterate :
    ?from:int ->
    ?to_:int ->
    t ->
    enter:(syntax_node -> bool) ->
    ?leave:(syntax_node -> unit) ->
    unit ->
    unit
  (** [Tree.iterate]. The callbacks are handed a stable {!SyntaxNode.t} (via the
      visited ref's [.node] accessor) rather than the lighter-weight
      [SyntaxNodeRef] JavaScript passes, trading a little efficiency for one
      node type throughout this binding; see {!SyntaxNode.t}. [enter] returning
      [false] skips the node's children, matching JavaScript's [false] (its
      [void]/undefined case, "continue", is [true] here since OCaml has no
      implicit return). *)

  val empty : t
end

(** {{:https://lezer.codemirror.net/docs/ref/#common.SyntaxNode}
     common.SyntaxNode}. [TreeCursor] (a mutable, more efficient traversal
    object) is not bound; use this and {!Tree.iterate} instead. *)
module SyntaxNode : sig
  type t = syntax_node

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val name : t -> string
  val from : t -> int
  val to_ : t -> int
  val type_ : t -> node_type
  val parent : t -> t option
  val first_child : t -> t option
  val last_child : t -> t option
  val child_after : t -> int -> t option
  val child_before : t -> int -> t option
  val next_sibling : t -> t option
  val prev_sibling : t -> t option
  val resolve : ?side:int -> t -> int -> t
  val resolve_inner : ?side:int -> t -> int -> t

  val enter : ?mode:int -> t -> pos:int -> side:int -> t option
  (** [mode] is JavaScript's [IterMode] bitmask, passed through as a raw [int];
      see {!Cm_language.IterMode} is not bound (only the numeric default, 0, is
      meaningful without it). *)

  val get_child : t -> string -> t option
  val get_children : t -> string -> t list
  val to_tree : t -> tree
  val match_context : t -> string list -> bool
end

(** {{:https://lezer.codemirror.net/docs/ref/#common.Parser} common.Parser}.
    Minimal: only a one-shot string parse. Incremental reparsing
    ([fragments]/[ranges]), and constructing a [Parser] from scratch, are not
    bound. *)
module Parser : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val parse : t -> string -> tree
end

(** {{:https://lezer.codemirror.net/docs/ref/#highlight.Tag} highlight.Tag} *)
module Tag : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val define : ?name:string -> ?parent:t -> unit -> t
  val define_modifier : ?name:string -> unit -> t -> t
  val set : t -> t list
end

(** {{:https://lezer.codemirror.net/docs/ref/#highlight.tags} highlight.tags}:
    every value of the default tag vocabulary, snake_cased. *)
module Tags : sig
  val comment : Tag.t
  val line_comment : Tag.t
  val block_comment : Tag.t
  val doc_comment : Tag.t
  val name : Tag.t
  val variable_name : Tag.t
  val type_name : Tag.t
  val tag_name : Tag.t
  val property_name : Tag.t
  val attribute_name : Tag.t
  val class_name : Tag.t
  val label_name : Tag.t
  val namespace : Tag.t
  val macro_name : Tag.t
  val literal : Tag.t
  val string : Tag.t
  val doc_string : Tag.t
  val character : Tag.t
  val attribute_value : Tag.t
  val number : Tag.t
  val integer : Tag.t
  val float : Tag.t
  val bool : Tag.t
  val regexp : Tag.t
  val escape : Tag.t
  val color : Tag.t
  val url : Tag.t
  val keyword : Tag.t
  val self : Tag.t
  val null_ : Tag.t
  val atom : Tag.t
  val unit : Tag.t
  val modifier : Tag.t
  val operator_keyword : Tag.t
  val control_keyword : Tag.t
  val definition_keyword : Tag.t
  val module_keyword : Tag.t
  val operator : Tag.t
  val deref_operator : Tag.t
  val arithmetic_operator : Tag.t
  val logic_operator : Tag.t
  val bitwise_operator : Tag.t
  val compare_operator : Tag.t
  val update_operator : Tag.t
  val definition_operator : Tag.t
  val type_operator : Tag.t
  val control_operator : Tag.t
  val punctuation : Tag.t
  val separator : Tag.t
  val bracket : Tag.t
  val angle_bracket : Tag.t
  val square_bracket : Tag.t
  val paren : Tag.t
  val brace : Tag.t
  val content : Tag.t
  val heading : Tag.t
  val heading1 : Tag.t
  val heading2 : Tag.t
  val heading3 : Tag.t
  val heading4 : Tag.t
  val heading5 : Tag.t
  val heading6 : Tag.t
  val content_separator : Tag.t
  val list : Tag.t
  val quote : Tag.t
  val emphasis : Tag.t
  val strong : Tag.t
  val link : Tag.t
  val monospace : Tag.t
  val strikethrough : Tag.t
  val inserted : Tag.t
  val deleted : Tag.t
  val changed : Tag.t
  val invalid : Tag.t
  val meta : Tag.t
  val document_meta : Tag.t
  val annotation : Tag.t
  val processing_instruction : Tag.t

  (* modifiers *)
  val definition : Tag.t -> Tag.t
  val constant : Tag.t -> Tag.t
  val function_ : Tag.t -> Tag.t
  val standard : Tag.t -> Tag.t
  val local : Tag.t -> Tag.t
  val special : Tag.t -> Tag.t
end

(** A
    {{:https://lezer.codemirror.net/docs/ref/#common.NodeProp^add}
     NodePropSource}, as produced by {!style_tags} and consumed by
    {!ParserConfig.create}'s [props]. *)
module NodePropSource : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
end

(** {{:https://lezer.codemirror.net/docs/ref/#lr.ParserConfig} lr.ParserConfig}.
    [tokenizers]/[specializers]/[contextTracker]/[wrap] are not bound; see "Not
    bound". *)
module ParserConfig : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create :
    ?props:NodePropSource.t list ->
    ?top:string ->
    ?dialect:string ->
    ?strict:bool ->
    ?buffer_length:int ->
    unit ->
    t
end

(** {{:https://lezer.codemirror.net/docs/ref/#lr.LRParser} lr.LRParser}. A
    ready-made parser, as exported by a generated grammar package; this binding
    does not construct one from scratch ([LRParser.deserialize] is not bound).
*)
module LRParser : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val to_parser : t -> Parser.t
  val configure : t -> ParserConfig.t -> t
  val has_wrappers : t -> bool
  val get_name : t -> int -> string
  val top_node : t -> node_type
end

(** {{:https://codemirror.net/docs/ref/#language.Language} language.Language}.
    Also the type produced by {!LRLanguage.to_language} and
    {!StreamLanguage.to_language}, since both are JavaScript subclasses of
    [Language]. *)
module Language : sig
  type t = language

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create :
    data:(Jv.t, Jv.t list) Facet.t ->
    parser:Parser.t ->
    ?extra_extensions:Extension.t list ->
    ?name:string ->
    unit ->
    t

  val data : t -> (Jv.t, Jv.t list) Facet.t
  val name : t -> string
  val extension : t -> Extension.t
  val parser : t -> Parser.t
  val is_active_at : t -> EditorState.t -> pos:int -> ?side:int -> unit -> bool
  val find_regions : t -> EditorState.t -> (int * int) list
  val allows_nesting : t -> bool
end

(** {{:https://codemirror.net/docs/ref/#language.LRLanguage}
     language.LRLanguage} *)
module LRLanguage : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val to_language : t -> language
  (** [LRLanguage] is a JavaScript subclass of [Language]; every {!Language.t}
      function works on the result. *)

  val define :
    ?name:string -> parser:LRParser.t -> ?language_data:Jv.t -> unit -> t

  val configure : t -> ?name:string -> ParserConfig.t -> t
  val parser : t -> LRParser.t
  val allows_nesting : t -> bool
end

(** {{:https://codemirror.net/docs/ref/#language.LanguageSupport}
     language.LanguageSupport} *)
module LanguageSupport : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val create : language -> ?support:Extension.t -> unit -> t
  val language : t -> language
  val support : t -> Extension.t

  val extension : t -> Extension.t
  (** the language plus its support extensions, bundled; this is what most
      callers install. *)
end

(** {{:https://codemirror.net/docs/ref/#language.LanguageDescription}
     language.LanguageDescription} *)
module LanguageDescription : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val name : t -> string
  val alias : t -> string list
  val extensions : t -> string list

  val filename : t -> Jv.t option
  (** a JavaScript [RegExp]; this binding does not wrap [RegExp], so it is
      passed through raw. *)

  val support : t -> LanguageSupport.t option
  val load : t -> LanguageSupport.t Fut.t

  val of_ :
    name:string ->
    ?alias:string list ->
    ?extensions:string list ->
    ?filename:Jv.t ->
    ?load:(unit -> LanguageSupport.t Fut.t) ->
    ?support:LanguageSupport.t ->
    unit ->
    t

  val match_filename : t list -> string -> t option
  val match_language_name : ?fuzzy:bool -> t list -> string -> t option
end

val language : (language, language option) Facet.t
(** {{:https://codemirror.net/docs/ref/#language.language} language.language} *)

val syntax_tree : EditorState.t -> tree
(** {{:https://codemirror.net/docs/ref/#language.syntaxTree}
     language.syntaxTree} *)

val ensure_syntax_tree :
  EditorState.t -> upto:int -> ?timeout:int -> unit -> tree option
(** {{:https://codemirror.net/docs/ref/#language.ensureSyntaxTree}
     language.ensureSyntaxTree} *)

val syntax_tree_available : EditorState.t -> ?upto:int -> unit -> bool
(** {{:https://codemirror.net/docs/ref/#language.syntaxTreeAvailable}
     language.syntaxTreeAvailable} *)

val force_parsing :
  Cm_view.editor_view -> ?upto:int -> ?timeout:int -> unit -> bool
(** {{:https://codemirror.net/docs/ref/#language.forceParsing}
     language.forceParsing} *)

val syntax_parser_running : Cm_view.editor_view -> bool
(** {{:https://codemirror.net/docs/ref/#language.syntaxParserRunning}
     language.syntaxParserRunning} *)

val language_data_prop : NodeProp.t
(** {{:https://codemirror.net/docs/ref/#language.languageDataProp}
     language.languageDataProp} *)

val language_data_of_node_type : node_type -> (Jv.t, Jv.t list) Facet.t option
(** decodes {!language_data_prop} off a node type, as
    {!Language.is_active_at}-adjacent code typically wants. *)

val define_language_facet : ?base_data:Jv.t -> unit -> (Jv.t, Jv.t list) Facet.t
(** {{:https://codemirror.net/docs/ref/#language.defineLanguageFacet}
     language.defineLanguageFacet} *)

val sublanguage_prop : NodeProp.t
(** {{:https://codemirror.net/docs/ref/#language.sublanguageProp}
     language.sublanguageProp}. Constructing and attaching a [Sublanguage] is
    not bound; see "Not bound". *)

(** {{:https://codemirror.net/docs/ref/#language.IndentContext}
     language.IndentContext} *)
module IndentContext : sig
  type t = indent_context

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create :
    ?override_indentation:(int -> int) ->
    ?simulate_break:int ->
    ?simulate_double_break:bool ->
    EditorState.t ->
    t

  val state : t -> EditorState.t
  val unit_ : t -> int

  val line_at : ?bias:int -> t -> int -> string * int
  (** [(text, from)]. *)

  val text_after_pos : ?bias:int -> t -> int -> string
  val column : ?bias:int -> t -> int -> int
  val count_column : ?pos:int -> t -> string -> int
  val line_indent : ?bias:int -> t -> int -> int
  val simulated_break : t -> int option
end

(** {{:https://codemirror.net/docs/ref/#language.TreeIndentContext}
     language.TreeIndentContext}. A read-only subclass of {!IndentContext}
    CodeMirror hands to indent strategies; there is no public constructor. *)
module TreeIndentContext : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val to_indent_context : t -> indent_context
  val node : t -> syntax_node
  val text_after : t -> string
  val base_indent : t -> int
  val base_indent_for : t -> syntax_node -> int
  val continue_ : t -> int option
  val pos : t -> int
end

type indent_result = [ `Indent of int | `None | `Defer ]
(** JavaScript's [number | null | undefined]: an indentation column, "no
    indentation can be determined" ([null]), or "defer to the next indent
    service" ([undefined]). *)

val indent_service : (indent_context -> pos:int -> indent_result, Jv.t) Facet.t
(** {{:https://codemirror.net/docs/ref/#language.indentService}
     language.indentService} *)

val indent_unit : (string, string) Facet.t
(** {{:https://codemirror.net/docs/ref/#language.indentUnit}
     language.indentUnit} *)

val get_indent_unit : EditorState.t -> int
(** {{:https://codemirror.net/docs/ref/#language.getIndentUnit}
     language.getIndentUnit} *)

val indent_string : EditorState.t -> int -> string
(** {{:https://codemirror.net/docs/ref/#language.indentString}
     language.indentString} *)

val get_indentation :
  [ `State of EditorState.t | `Context of indent_context ] ->
  pos:int ->
  int option
(** {{:https://codemirror.net/docs/ref/#language.getIndentation}
     language.getIndentation} *)

val indent_range : EditorState.t -> from:int -> to_:int -> ChangeSet.t
(** {{:https://codemirror.net/docs/ref/#language.indentRange}
     language.indentRange} *)

val indent_node_prop : NodeProp.t
(** {{:https://codemirror.net/docs/ref/#language.indentNodeProp}
     language.indentNodeProp}. Attaching a strategy to a custom node type is not
    bound; see "Not bound". *)

val delimited_indent :
  closing:string ->
  ?align:bool ->
  ?units:int ->
  unit ->
  TreeIndentContext.t ->
  int
(** {{:https://codemirror.net/docs/ref/#language.delimitedIndent}
     language.delimitedIndent} *)

val flat_indent : TreeIndentContext.t -> int
(** {{:https://codemirror.net/docs/ref/#language.flatIndent}
     language.flatIndent} *)

val continued_indent : ?units:int -> unit -> TreeIndentContext.t -> int
(** {{:https://codemirror.net/docs/ref/#language.continuedIndent}
     language.continuedIndent}. Drops [except] (a JavaScript [RegExp]); this
    binding does not wrap [RegExp]. *)

val indent_on_input : unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#language.indentOnInput}
     language.indentOnInput} *)

(** {{:https://codemirror.net/docs/ref/#language.StringStream}
     language.StringStream}: the input a {!StreamParser.t}'s [token] tokenizes.
    Matching against a JavaScript [RegExp] ([eat]/[match]'s pattern forms) is
    not bound; [eat]/[eat_while] take an OCaml character predicate instead, and
    {!match_} only its plain-string form. *)
module StringStream : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val string : t -> string
  val pos : t -> int
  val start : t -> int
  val indent_unit : t -> int
  val eol : t -> bool
  val sol : t -> bool
  val peek : t -> string option
  val next : t -> string option
  val eat : t -> (string -> bool) -> string option
  val eat_while : t -> (string -> bool) -> bool
  val eat_space : t -> bool
  val skip_to_end : t -> unit
  val skip_to : t -> string -> bool
  val back_up : t -> int -> unit
  val column : t -> int
  val indentation : t -> int

  val match_ : t -> ?consume:bool -> ?case_insensitive:bool -> string -> bool
  (** [StringStream.match]'s plain-string form; see the module note. *)

  val current : t -> string
end

(** {{:https://codemirror.net/docs/ref/#language.StreamParser}
     language.StreamParser}: the record of callbacks {!StreamLanguage.define}
    takes. The parser's internal ['state] never appears in {!t} (it is threaded
    opaquely between the callbacks {!create} is given, via
    {!Brr.Jv.repr}/{!Jv.CONV.of_jv}-style identity casts under the hood, the
    same escape hatch {!Cm_state.Conv.callback} formalizes for functions); see
    the friction notes in DESIGN.md. *)
module StreamParser : sig
  type t

  include Jv.CONV with type t := t
  (** [of_jv] also wraps a plain JavaScript mode object exported by another
      package, such as [\@codemirror/legacy-modes]'s per-language values. *)

  val conv : t Conv.t

  val create :
    token:(StringStream.t -> 'state -> string option) ->
    ?name:string ->
    ?start_state:(indent_unit:int -> 'state) ->
    ?copy_state:('state -> 'state) ->
    ?indent:('state -> text_after:string -> indent_context -> int option) ->
    ?blank_line:('state -> indent_unit:int -> unit) ->
    ?language_data:Jv.t ->
    ?token_table:(string * Tag.t list) list ->
    ?merge_tokens:bool ->
    unit ->
    t
  (** If [start_state] is omitted, the initial state is [Jv.repr ()]; a stateful
      parser must supply [start_state]. If [copy_state] is omitted, this binding
      defaults to the identity function (not JavaScript's own
      shallow-object-copy default, which is unsafe against an opaque js_of_ocaml
      value); see DESIGN.md. *)
end

(** {{:https://codemirror.net/docs/ref/#language.StreamLanguage}
     language.StreamLanguage}: a [Language] subclass wrapping a
    {!StreamParser.t}. *)
module StreamLanguage : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val to_language : t -> language
  (** [StreamLanguage] is a JavaScript subclass of [Language]; every
      {!Language.t} function works on the result. *)

  val define : StreamParser.t -> t
  val allows_nesting : t -> bool
end

(** A
    {{:https://lezer.codemirror.net/docs/ref/#highlight.Highlighter}
     highlight.Highlighter}: {!HighlightStyle.t} values (via
    {!HighlightStyle.to_highlighter}), {!class_highlighter} and
    {!tag_highlighter}'s results are all one. *)
module Highlighter : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
end

(** The [class]/style-mod-properties spec {!HighlightStyle.define} takes per tag
    group.
    {{:https://codemirror.net/docs/ref/#language.TagStyle} language.TagStyle} *)
module TagStyle : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val make : ?class_:string -> ?style:Cm_view.StyleSpec.t -> Tag.t list -> t
  (** [class_] only puts the class on the matching spans; the page must supply a
      rule for it. [style] carries the declarations itself. *)
end

(** {{:https://codemirror.net/docs/ref/#language.HighlightStyle}
     language.HighlightStyle} *)
module HighlightStyle : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val to_highlighter : t -> Highlighter.t

  val define :
    ?scope:[ `Language of language | `Node_type of node_type ] ->
    ?all:[ `Class of string | `Style of Cm_view.StyleSpec.t ] ->
    ?theme_type:[ `Dark | `Light ] ->
    TagStyle.t list ->
    t
end

val default_highlight_style : HighlightStyle.t
(** {{:https://codemirror.net/docs/ref/#language.defaultHighlightStyle}
     language.defaultHighlightStyle} *)

val syntax_highlighting : ?fallback:bool -> HighlightStyle.t -> Extension.t
(** {{:https://codemirror.net/docs/ref/#language.syntaxHighlighting}
     language.syntaxHighlighting} *)

val highlighting_for :
  EditorState.t -> Tag.t list -> ?scope:node_type -> unit -> string option
(** {{:https://codemirror.net/docs/ref/#language.highlightingFor}
     language.highlightingFor} *)

val style_tags : (string * Tag.t list) list -> NodePropSource.t
(** {{:https://lezer.codemirror.net/docs/ref/#highlight.styleTags}
     highlight.styleTags} *)

val tag_highlighter :
  ?scope:(node_type -> bool) ->
  ?all:string ->
  (Tag.t list * string) list ->
  Highlighter.t
(** {{:https://lezer.codemirror.net/docs/ref/#highlight.tagHighlighter}
     highlight.tagHighlighter} *)

val class_highlighter : Highlighter.t
(** {{:https://lezer.codemirror.net/docs/ref/#highlight.classHighlighter}
     highlight.classHighlighter} *)

val highlight_tree :
  ?from:int ->
  ?to_:int ->
  tree ->
  Highlighter.t list ->
  (from:int -> to_:int -> classes:string -> unit) ->
  unit
(** {{:https://lezer.codemirror.net/docs/ref/#highlight.highlightTree}
     highlight.highlightTree} *)

val highlight_code :
  ?from:int ->
  ?to_:int ->
  string ->
  tree ->
  Highlighter.t list ->
  put_text:(string -> classes:string -> unit) ->
  put_break:(unit -> unit) ->
  unit ->
  unit
(** {{:https://lezer.codemirror.net/docs/ref/#highlight.highlightCode}
     highlight.highlightCode} *)

type style_tags_result = { tags : Tag.t list; opaque : bool; inherit_ : bool }

val get_style_tags : syntax_node -> style_tags_result option
(** {{:https://lezer.codemirror.net/docs/ref/#highlight.getStyleTags}
     highlight.getStyleTags} *)

val fold_service :
  ( EditorState.t -> line_start:int -> line_end:int -> (int * int) option,
    Jv.t )
  Facet.t
(** {{:https://codemirror.net/docs/ref/#language.foldService}
     language.foldService} *)

val fold_node_prop : NodeProp.t
(** {{:https://codemirror.net/docs/ref/#language.foldNodeProp}
     language.foldNodeProp}. Attaching a strategy to a custom node type is not
    bound; see "Not bound". *)

val fold_inside : syntax_node -> (int * int) option
(** {{:https://codemirror.net/docs/ref/#language.foldInside}
     language.foldInside} *)

val foldable :
  EditorState.t -> line_start:int -> line_end:int -> (int * int) option
(** {{:https://codemirror.net/docs/ref/#language.foldable} language.foldable} *)

val fold_effect : (int * int) StateEffectType.t
(** {{:https://codemirror.net/docs/ref/#language.foldEffect}
     language.foldEffect} *)

val unfold_effect : (int * int) StateEffectType.t
(** {{:https://codemirror.net/docs/ref/#language.unfoldEffect}
     language.unfoldEffect} *)

val folded_ranges : EditorState.t -> Cm_view.Decoration.t RangeSet.t
(** {{:https://codemirror.net/docs/ref/#language.foldedRanges}
     language.foldedRanges}. The [foldState] field itself is not bound: it is a
    [StateField] CodeMirror defines internally, and {!Cm_state.StateField.t} has
    no public constructor from a raw JavaScript [StateField] (only [define]
    makes one); this free function reads the same information. *)

val fold_code : Cm_view.command
(** {{:https://codemirror.net/docs/ref/#language.foldCode} language.foldCode} *)

val unfold_code : Cm_view.command
(** {{:https://codemirror.net/docs/ref/#language.unfoldCode}
     language.unfoldCode} *)

val fold_all : Cm_view.command
(** {{:https://codemirror.net/docs/ref/#language.foldAll} language.foldAll} *)

val unfold_all : Cm_view.command
(** {{:https://codemirror.net/docs/ref/#language.unfoldAll} language.unfoldAll}
*)

val toggle_fold : Cm_view.command
(** {{:https://codemirror.net/docs/ref/#language.toggleFold}
     language.toggleFold} *)

val fold_keymap : Cm_view.KeyBinding.t list
(** {{:https://codemirror.net/docs/ref/#language.foldKeymap}
     language.foldKeymap} *)

val code_folding : ?placeholder_text:string -> unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#language.codeFolding}
     language.codeFolding}. Drops [placeholderDOM]/[preparePlaceholder] (a
    DOM-building callback pair); [placeholder_text] covers the common case. *)

val fold_gutter :
  ?open_text:string ->
  ?closed_text:string ->
  ?dom_event_handlers:
    (string
    * (Cm_view.editor_view ->
      Cm_view.BlockInfo.t ->
      Brr.Ev.void Brr.Ev.t ->
      bool))
    list ->
  ?folding_changed:(Cm_view.ViewUpdate.t -> bool) ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#language.foldGutter}
     language.foldGutter}. Drops [markerDOM] (a DOM-building callback);
    [open_text]/[closed_text] cover the common case. *)

type match_result = {
  start : int * int;
  end_ : (int * int) option;
  matched : bool;
}

val bracket_matching :
  ?after_cursor:bool ->
  ?brackets:string ->
  ?max_scan_distance:int ->
  ?render_match:
    (match_result -> EditorState.t -> Cm_view.Decoration.t Range.t list) ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#language.bracketMatching}
     language.bracketMatching} *)

val bracket_matching_handle : NodeProp.t
(** {{:https://codemirror.net/docs/ref/#language.bracketMatchingHandle}
     language.bracketMatchingHandle} *)

val match_brackets :
  EditorState.t ->
  pos:int ->
  dir:[ `Backward | `Forward ] ->
  ?brackets:string ->
  ?max_scan_distance:int ->
  unit ->
  match_result option
(** {{:https://codemirror.net/docs/ref/#language.matchBrackets}
     language.matchBrackets} *)

val bidi_isolates : ?always_isolate:bool -> unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#language.bidiIsolates}
     language.bidiIsolates} *)

(** Not bound:

    - [ParseContext], [DocInput], [TreeFragment], [PartialParse], the [Input]
      interface, [parseMixed]/[NestedParse]: the machinery for writing a
      brand-new incremental [Parser]/[Language] integrated with CodeMirror's
      background parse scheduler. {!StreamLanguage} and {!LRLanguage} cover the
      paths this binding's consumers actually take (wrapping a stream-style
      tokenizer, or installing a pre-built [\@lezer/generator] parser); building
      the scheduler integration itself is out of scope.
    - [NodeProp.define]/[NodeProp.add], and so anything that attaches a strategy
      to a *custom* node type via a node prop ([indentNodeProp], [foldNodeProp],
      [sublanguageProp], [bracketMatchingHandle] as *write* targets,
      [NodeType.define]'s [props]): the value type of a custom prop is only
      known by convention, and expressing "a typed prop, generically" needs
      machinery this binding's [Conv.t] style does not reach for cheaply. The
      library's own predefined instances are still read, via {!NodeProp.t} and
      {!NodeType.prop}.
    - [Sublanguage] construction: needs the same [NodeProp.add] machinery; only
      {!sublanguage_prop}, the raw prop constant, is exposed.
    - [TreeCursor], [NodeWeakMap], [Tree.build], [TreeBuffer], [BufferCursor],
      [NodeSet]/[NodeSet.extend], [MountedTree] construction: the low-level
      tree-representation API used by parser generators and custom [Parser]s,
      not by consumers of an already-built parser.
    - [ContextTracker], [ExternalTokenizer], [InputStream], [Stack],
      [LocalTokenGroup], and so [ParserConfig]'s [tokenizers]/
      [specializers]/[contextTracker]/[wrap]: LR-parser internals used only when
      hand-writing a new grammar with external tokenizers; consumers of this
      binding use an already-generated [LRParser].
    - [LRParser.deserialize]: internal, used only by [\@lezer/generator]'s own
      output; a generated parser package already exports a ready [LRParser]
      value.
    - [IterMode] as a named type: {!SyntaxNode.enter}/[Tree.cursorAt]'s mode
      bitmask is passed through as a raw [int] (JavaScript's default, [0], is
      the only value this binding's own functions need).
    - [StringStream.eat]/[eatWhile]/[match]'s [string]/[RegExp] pattern forms,
      and [continuedIndent]'s [except]: this binding does not wrap [RegExp];
      predicates and plain strings cover the rest.
    - [LanguageDescription.filename]'s [RegExp] value: passed through as a raw
      {!Jv.t}, for the same reason.
    - [FoldConfig.placeholderDOM]/[preparePlaceholder] and
      [FoldGutterConfig.markerDOM]: DOM-building callback pairs;
      [placeholder_text]/[open_text]/[closed_text] cover the default,
      commonly-used styling.
    - [foldState] as a {!Cm_state.StateField.t}: see {!folded_ranges}'s doc
      comment. *)
