(** {{:https://codemirror.net/docs/ref/#search} \@codemirror/search}: the search
    panel, its commands, and the [SearchCursor]/[RegExpCursor] iterators used to
    drive a search over a document directly. *)

open Cm_state
open Cm_view

type match_ = { from : int; to_ : int }
(** A single match of a {!SearchCursor}: the range it covers.
    {{:https://codemirror.net/docs/ref/#search.SearchCursor}
     search.SearchCursor} *)

(** A search cursor over plain-string (or literal) matches. JavaScript's
    [SearchCursor] is a stateful, mutating iterator ([next()] mutates and
    returns [this]; [value]/[done] are read off the same object); rather than
    exposing that protocol, {!next} and {!next_overlapping} return the match (or
    [None] at the end), and {!fold}/{!iter} drive the cursor to completion. See
    DESIGN.md's friction notes for why. *)
module SearchCursor : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?from:int ->
    ?to_:int ->
    ?normalize:(string -> string) ->
    ?test:(from:int -> to_:int -> buffer:string -> buffer_pos:int -> bool) ->
    Text.t ->
    string ->
    t
  (** [create ?from ?to_ ?normalize ?test text query]: [query] is the search
      string, [from]/[to_] the region of [text] to search. [normalize], when
      given, is applied to the query and to matched text before comparing (e.g.
      lower-casing both for a case-insensitive search); text is always also
      normalized with Unicode [NFKD] first. *)

  val next : t -> match_ option
  (** Advance to the next match, ignoring matches that partially overlap a
      previous one. [None] once the cursor is exhausted. *)

  val next_overlapping : t -> match_ option
  (** Like {!next}, but includes matches that partially overlap a previous one.
  *)

  val fold : t -> init:'a -> (match_ -> 'a -> 'a) -> 'a
  (** Drives {!next} to completion, folding over every match. *)

  val iter : t -> (match_ -> unit) -> unit
  (** Drives {!next} to completion, calling [f] on every match. *)
end

type regexp_match = { from : int; to_ : int; captures : string option array }
(** A match of a {!RegExpCursor}: the range it covers, and the regular
    expression's capture groups (index 0 is the whole match; [None] for a group
    that did not participate). *)

(** A search cursor over regular-expression matches.
    {{:https://codemirror.net/docs/ref/#search.RegExpCursor}
     search.RegExpCursor}. See {!SearchCursor} for why this binds
    [next]/[fold]/[iter] rather than the JavaScript iterator protocol directly.
*)
module RegExpCursor : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?ignore_case:bool ->
    ?test:(from:int -> to_:int -> captures:string option array -> bool) ->
    ?from:int ->
    ?to_:int ->
    Text.t ->
    string ->
    t
  (** [create ?ignore_case ?test ?from ?to_ text query]: [query] is the raw
      pattern, as passed to JavaScript's [RegExp]. *)

  val next : t -> regexp_match option
  val fold : t -> init:'a -> (regexp_match -> 'a -> 'a) -> 'a
  val iter : t -> (regexp_match -> unit) -> unit
end

val goto_line : command
(** {{:https://codemirror.net/docs/ref/#search.gotoLine} search.gotoLine}. Opens
    a dialog asking for a line number (or a [+]/[-] relative offset, a [%]
    percentage, or [line:column]) and moves the cursor there. *)

val highlight_selection_matches :
  ?highlight_word_around_cursor:bool ->
  ?min_selection_length:int ->
  ?max_matches:int ->
  ?whole_words:bool ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#search.highlightSelectionMatches}
     search.highlightSelectionMatches}. Highlights text matching the selection
    with the ["cm-selectionMatch"] class (and ["cm-selectionMatch-main"] for the
    word at the cursor, when [highlight_word_around_cursor] is set). *)

val select_next_occurrence : command
(** {{:https://codemirror.net/docs/ref/#search.selectNextOccurrence}
     search.selectNextOccurrence}. JavaScript's [StateCommand]: called the same
    way as a {!command} here, since an {!editor_view} satisfies the
    [{state, dispatch}] shape it expects. See DESIGN.md's friction notes. *)

val search :
  ?top:bool ->
  ?case_sensitive:bool ->
  ?literal:bool ->
  ?whole_word:bool ->
  ?regexp:bool ->
  ?create_panel:(editor_view -> Panel.t) ->
  ?scroll_to_match:(SelectionRange.t -> editor_view -> StateEffect.t) ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#search.search} search.search}. Adds
    search state to the editor, and optionally configures it. *)

(** A search query: [search] text (or pattern), its flags, and any pending
    replacement text. Part of the editor's search state; see
    {!set_search_query}/{!get_search_query}.
    {{:https://codemirror.net/docs/ref/#search.SearchQuery} search.SearchQuery}
*)
module SearchQuery : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create :
    search:string ->
    ?case_sensitive:bool ->
    ?literal:bool ->
    ?regexp:bool ->
    ?replace:string ->
    ?whole_word:bool ->
    unit ->
    t

  val search : t -> string
  val case_sensitive : t -> bool
  val literal : t -> bool
  val regexp : t -> bool
  val replace : t -> string
  val valid : t -> bool
  val whole_word : t -> bool
  val eq : t -> t -> bool

  val get_cursor :
    t ->
    ?from:int ->
    ?to_:int ->
    [ `State of EditorState.t | `Doc of Text.t ] ->
    SearchCursor.t
  (** A cursor over this query's matches between [from] and [to_]. JavaScript's
      return type is an anonymous iterator interface, not a named class; even
      when the query is a regexp (so the runtime object is really a
      {!RegExpCursor}), only the plain [from]/[to] shape is exposed, which is
      exactly {!SearchCursor}'s public surface, so that is what this returns.
      See DESIGN.md's friction notes. *)
end

val set_search_query : SearchQuery.t StateEffectType.t
(** {{:https://codemirror.net/docs/ref/#search.setSearchQuery}
     search.setSearchQuery}. Only takes effect once the search state has been
    initialized, by {!search} or a first call to {!open_search_panel}. *)

val get_search_query : EditorState.t -> SearchQuery.t
(** {{:https://codemirror.net/docs/ref/#search.getSearchQuery}
     search.getSearchQuery} *)

val search_panel_open : EditorState.t -> bool
(** {{:https://codemirror.net/docs/ref/#search.searchPanelOpen}
     search.searchPanelOpen} *)

val find_next : command
(** {{:https://codemirror.net/docs/ref/#search.findNext} search.findNext} *)

val find_previous : command
(** {{:https://codemirror.net/docs/ref/#search.findPrevious}
     search.findPrevious} *)

val select_matches : command
(** {{:https://codemirror.net/docs/ref/#search.selectMatches}
     search.selectMatches} *)

val select_selection_matches : command
(** {{:https://codemirror.net/docs/ref/#search.selectSelectionMatches}
     search.selectSelectionMatches}. A [StateCommand]; see
    {!select_next_occurrence}. *)

val replace_next : command
(** {{:https://codemirror.net/docs/ref/#search.replaceNext} search.replaceNext}
*)

val replace_all : command
(** {{:https://codemirror.net/docs/ref/#search.replaceAll} search.replaceAll} *)

val open_search_panel : command
(** {{:https://codemirror.net/docs/ref/#search.openSearchPanel}
     search.openSearchPanel} *)

val close_search_panel : command
(** {{:https://codemirror.net/docs/ref/#search.closeSearchPanel}
     search.closeSearchPanel} *)

val search_keymap : KeyBinding.t list
(** {{:https://codemirror.net/docs/ref/#search.searchKeymap}
     search.searchKeymap} *)

(** Not bound:

    - [RegExpExecArray]'s named capture groups ([.groups]) and its [.index]/
      [.input] properties: {!regexp_match} keeps the numbered captures
      ([.match]'s array elements) and the [from]/[to_] range already given by
      the outer object; the named-group map would need a general JavaScript
      object-to-association-list decoder this package does not otherwise need.
    - [SearchCursor]/[RegExpCursor]'s [[Symbol.iterator]]: superseded by
      {!SearchCursor.fold}/{!SearchCursor.iter} and their [RegExpCursor]
      counterparts. *)
