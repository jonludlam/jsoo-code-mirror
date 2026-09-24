(** {{:https://codemirror.net/docs/ref/#autocomplete} \@codemirror/autocomplete}:
    completion sources and the popup that shows them, bracket closing, and
    snippet expansion. *)

open Cm_state
open Cm_view

(** {{:https://codemirror.net/docs/ref/#autocomplete.Completion}
     autocomplete.Completion} *)
module Completion : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  (** {{:https://codemirror.net/docs/ref/#autocomplete.CompletionSection}
       autocomplete.CompletionSection}. [header], a DOM-building callback, is
      not bound (see {!Cm_view.WidgetType.make}'s [to_dom] for the same
      trade-off elsewhere in this library: only the constructible parts of a
      config are bound, not the ones that hand back a live DOM node to be built
      lazily). *)
  module Section : sig
    type t

    include Jv.CONV with type t := t

    val conv : t Conv.t
    val make : ?rank:int -> string -> t
    val name : t -> string
    val rank : t -> int option
  end

  val create :
    label:string ->
    ?display_label:string ->
    ?detail:string ->
    ?info:[ `Text of string | `Render of t -> Brr.El.t ] ->
    ?apply:
      [ `Text of string
      | `Apply of EditorView.t -> t -> from:int -> to_:int -> unit ] ->
    ?type_:string ->
    ?boost:int ->
    ?section:[ `Name of string | `Section of Section.t ] ->
    ?commit_characters:string list ->
    unit ->
    t
  (** [info]'s JavaScript type is
      [string | ((Completion) => CompletionInfo | Promise<CompletionInfo>)], and
      [CompletionInfo] is itself [Node | null | {dom, destroy?}]; only the plain
      string and the synchronous element-returning function are bound, matching
      the DOM-callback fields elsewhere in this library
      ({!Cm_lint.Diagnostic.create}'s [rendered_message],
      {!Cm_view.WidgetType.make}'s [to_dom]). [apply] is a JavaScript union of a
      plain string and a function, which CONVENTIONS.md's
      boolean/string-constant rule doesn't literally cover, but the same
      reasoning applies: the two cases are genuinely different things to do, so
      this is a polymorphic variant rather than trying to unify them. *)

  val label : t -> string
  val display_label : t -> string option
  val detail : t -> string option
  val type_ : t -> string option
  val boost : t -> int option
  val commit_characters : t -> string list option
end

(** {{:https://codemirror.net/docs/ref/#autocomplete.CompletionContext}
     autocomplete.CompletionContext} *)
module CompletionContext : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create :
    EditorState.t -> pos:int -> explicit:bool -> ?view:EditorView.t -> unit -> t
  (** Mostly useful for testing completion sources; in the editor, the
      [autocompletion] extension creates these for you. *)

  val state : t -> EditorState.t
  val pos : t -> int
  val explicit : t -> bool

  val view : t -> EditorView.t option
  (** [None] when the context was created without a view, e.g. by {!create} or
      from {!CompletionResult.t}'s [update]. *)

  type token = {
    from : int;
    to_ : int;
    text : string;
    type_ : Cm_language.NodeType.t;
  }

  val token_before : t -> string list -> token option
  (** {{:https://codemirror.net/docs/ref/#autocomplete.CompletionContext.tokenBefore}
       CompletionContext.tokenBefore} *)

  type match_ = { from : int; to_ : int; text : string }

  val match_before : t -> Jv.t -> match_ option
  (** {{:https://codemirror.net/docs/ref/#autocomplete.CompletionContext.matchBefore}
       CompletionContext.matchBefore}. The expression is a JavaScript [RegExp],
      passed through as a raw {!Jv.t}; this binding does not reintroduce a
      [RegExp] module (see DESIGN.md). *)

  val aborted : t -> bool

  val add_event_listener : ?on_doc_change:bool -> t -> (unit -> unit) -> unit
  (** [addEventListener("abort", listener, {onDocChange})]. The event type is
      fixed to ["abort"], the only one CodeMirror defines. *)
end

(** {{:https://codemirror.net/docs/ref/#autocomplete.CompletionResult}
     autocomplete.CompletionResult} *)
module CompletionResult : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create :
    from:int ->
    ?to_:int ->
    options:Completion.t list ->
    ?valid_for:
      [ `Regexp of Jv.t
      | `Predicate of string -> from:int -> to_:int -> EditorState.t -> bool ] ->
    ?filter:bool ->
    ?get_match:(Completion.t -> ?matched:int list -> unit -> int list) ->
    ?update:(t -> from:int -> to_:int -> CompletionContext.t -> t option) ->
    ?map:(t -> ChangeDesc.t -> t option) ->
    ?commit_characters:string list ->
    unit ->
    t
  (** [valid_for]'s [`Regexp] case is a raw JavaScript [RegExp], as
      {!CompletionContext.match_before}. *)

  val from : t -> int
  val to_ : t -> int option
  val options : t -> Completion.t list
  val filter : t -> bool option
  val commit_characters : t -> string list option
end

type completion_source = CompletionContext.t -> CompletionResult.t option Fut.t
(** {{:https://codemirror.net/docs/ref/#autocomplete.CompletionSource}
     autocomplete.CompletionSource}. May return its result synchronously; wrap a
    synchronous result with [Fut.return] (see {!Cm_view.hover_tooltip}). *)

val completion_source_conv : completion_source Conv.t
(** For a source in language data, as in
    [Facet.of_ (Language.data lang) (Jv.obj [| ("autocomplete",
     completion_source_conv.to_jv source) |])]. *)

val complete_from_list : Completion.t list -> completion_source
(** {{:https://codemirror.net/docs/ref/#autocomplete.completeFromList}
     autocomplete.completeFromList} *)

val complete_any_word : completion_source
(** {{:https://codemirror.net/docs/ref/#autocomplete.completeAnyWord}
     autocomplete.completeAnyWord} *)

val if_in : string list -> completion_source -> completion_source
(** {{:https://codemirror.net/docs/ref/#autocomplete.ifIn} autocomplete.ifIn} *)

val if_not_in : string list -> completion_source -> completion_source
(** {{:https://codemirror.net/docs/ref/#autocomplete.ifNotIn}
     autocomplete.ifNotIn} *)

val insert_completion_text :
  EditorState.t -> text:string -> from:int -> to_:int -> TransactionSpec.t
(** {{:https://codemirror.net/docs/ref/#autocomplete.insertCompletionText}
     autocomplete.insertCompletionText} *)

val picked_completion : Completion.t AnnotationType.t
(** {{:https://codemirror.net/docs/ref/#autocomplete.pickedCompletion}
     autocomplete.pickedCompletion}: the annotation added to transactions
    produced by picking a completion. *)

type add_to_option = {
  render : Completion.t -> EditorState.t -> EditorView.t -> Brr.El.t option;
  position : int;
}
(** One entry of [autocompletion]'s [add_to_options]; matches JavaScript's
    [{render, position}]. Declared ahead of {!autocompletion}, the same ad hoc
    placement {!Cm_state}'s [change_by_range_result] and {!Cm_view}'s
    [mouse_selection_style] use. *)

type position_info_result = { style : string option; class_ : string option }
(** What [autocompletion]'s [position_info] returns. *)

val autocompletion :
  ?activate_on_typing:bool ->
  ?activate_on_completion:(Completion.t -> bool) ->
  ?activate_on_typing_delay:int ->
  ?select_on_open:bool ->
  ?override:completion_source list ->
  ?close_on_blur:bool ->
  ?max_rendered_options:int ->
  ?default_keymap:bool ->
  ?above_cursor:bool ->
  ?tooltip_class:(EditorState.t -> string) ->
  ?option_class:(Completion.t -> string) ->
  ?icons:bool ->
  ?add_to_options:add_to_option list ->
  ?position_info:
    (EditorView.t ->
    list:Rect.t ->
    option:Rect.t ->
    info:Rect.t ->
    space:Rect.t ->
    position_info_result) ->
  ?compare_completions:(Completion.t -> Completion.t -> int) ->
  ?filter_strict:bool ->
  ?interaction_delay:int ->
  ?update_sync_time:int ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#autocomplete.autocompletion}
     autocomplete.autocompletion}. [override]'s JavaScript [null] (turn
    completion off entirely) has no separate case here: pass [~override:[]] for
    "no sources". *)

val completion_keymap : KeyBinding.t list
(** {{:https://codemirror.net/docs/ref/#autocomplete.completionKeymap}
     autocomplete.completionKeymap} *)

val move_completion_selection :
  forward:bool -> ?by:[ `Option | `Page ] -> unit -> command
(** {{:https://codemirror.net/docs/ref/#autocomplete.moveCompletionSelection}
     autocomplete.moveCompletionSelection} *)

val accept_completion : command
(** {{:https://codemirror.net/docs/ref/#autocomplete.acceptCompletion}
     autocomplete.acceptCompletion} *)

val start_completion : command
(** {{:https://codemirror.net/docs/ref/#autocomplete.startCompletion}
     autocomplete.startCompletion} *)

val close_completion : command
(** {{:https://codemirror.net/docs/ref/#autocomplete.closeCompletion}
     autocomplete.closeCompletion} *)

val completion_status : EditorState.t -> [ `Active | `Pending ] option
(** {{:https://codemirror.net/docs/ref/#autocomplete.completionStatus}
     autocomplete.completionStatus} *)

val current_completions : EditorState.t -> Completion.t list
(** {{:https://codemirror.net/docs/ref/#autocomplete.currentCompletions}
     autocomplete.currentCompletions} *)

val selected_completion : EditorState.t -> Completion.t option
(** {{:https://codemirror.net/docs/ref/#autocomplete.selectedCompletion}
     autocomplete.selectedCompletion} *)

val selected_completion_index : EditorState.t -> int option
(** {{:https://codemirror.net/docs/ref/#autocomplete.selectedCompletionIndex}
     autocomplete.selectedCompletionIndex} *)

val set_selected_completion : int -> StateEffect.t
(** {{:https://codemirror.net/docs/ref/#autocomplete.setSelectedCompletion}
     autocomplete.setSelectedCompletion} *)

(** {{:https://codemirror.net/docs/ref/#autocomplete.CloseBracketConfig}
     autocomplete.CloseBracketConfig}: the shape of the ["closeBrackets"]
    language-data entry {!close_brackets} reads. *)
module CloseBracketConfig : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create :
    ?brackets:string list ->
    ?before:string ->
    ?string_prefixes:string list ->
    unit ->
    t
end

val close_brackets : unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#autocomplete.closeBrackets}
     autocomplete.closeBrackets} *)

val close_brackets_keymap : KeyBinding.t list
(** {{:https://codemirror.net/docs/ref/#autocomplete.closeBracketsKeymap}
     autocomplete.closeBracketsKeymap} *)

val delete_bracket_pair : command
(** {{:https://codemirror.net/docs/ref/#autocomplete.deleteBracketPair}
     autocomplete.deleteBracketPair} *)

val insert_bracket : EditorState.t -> bracket:string -> Transaction.t option
(** {{:https://codemirror.net/docs/ref/#autocomplete.insertBracket}
     autocomplete.insertBracket} *)

val snippet :
  string -> EditorView.t -> Completion.t option -> from:int -> to_:int -> unit
(** {{:https://codemirror.net/docs/ref/#autocomplete.snippet}
     autocomplete.snippet}: converts a snippet template to the function that
    applies it. The editor argument is JavaScript's duck-typed
    [{state, dispatch}], which {!Cm_view.EditorView.t} satisfies structurally,
    as elsewhere in this library (see [@codemirror/search]'s command values). *)

val snippet_completion : template:string -> Completion.t -> Completion.t
(** {{:https://codemirror.net/docs/ref/#autocomplete.snippetCompletion}
     autocomplete.snippetCompletion}: builds a completion whose [apply] runs the
    snippet. *)

val snippet_keymap : (KeyBinding.t list, KeyBinding.t list) Facet.t
(** {{:https://codemirror.net/docs/ref/#autocomplete.snippetKeymap}
     autocomplete.snippetKeymap} *)

val clear_snippet : command
(** {{:https://codemirror.net/docs/ref/#autocomplete.clearSnippet}
     autocomplete.clearSnippet} *)

val next_snippet_field : command
(** {{:https://codemirror.net/docs/ref/#autocomplete.nextSnippetField}
     autocomplete.nextSnippetField} *)

val prev_snippet_field : command
(** {{:https://codemirror.net/docs/ref/#autocomplete.prevSnippetField}
     autocomplete.prevSnippetField} *)

val has_next_snippet_field : EditorState.t -> bool
(** {{:https://codemirror.net/docs/ref/#autocomplete.hasNextSnippetField}
     autocomplete.hasNextSnippetField} *)

val has_prev_snippet_field : EditorState.t -> bool
(** {{:https://codemirror.net/docs/ref/#autocomplete.hasPrevSnippetField}
     autocomplete.hasPrevSnippetField} *)

(** Not bound:

    - The asynchronous ([Promise]-returning) and [{dom, destroy?}] forms of
      [Completion.info]: only the plain string and the synchronous,
      element-returning function form are bound; see {!Completion.create}.
    - [CompletionSection.header]: a DOM-building callback, dropped the same way
      [@codemirror/language]'s [FoldConfig.placeholderDOM] and
      [@codemirror/view]'s panel/tooltip DOM builders are, in favor of the
      value-returning parts of the config.
    - [CompletionContext]'s private constructor overload details beyond the one
      public [create] above: the class has no other public surface. *)
