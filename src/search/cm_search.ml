open Cm_state
open Cm_view

let pkg = lazy (Jv.get Jv.global "__CM__search")

(* Small helpers, matching src/view/cm_view.ml: an absent optional argument
   becomes [undefined], relying on JavaScript's own default parameters. *)
let opt_int = Jv.of_option ~none:Jv.undefined Jv.of_int

(* A raw exported Command/StateCommand value, called against an editor_view
   the way CodeMirror itself calls it (both accept a view as their target). *)
let command_of_jv (raw : Jv.t) : command =
 fun (view : editor_view) ->
  Jv.apply raw [| EditorView.to_jv view |] |> Jv.to_bool

type match_ = { from : int; to_ : int }

let match_of_jv (v : Jv.t) : match_ =
  { from = Jv.Int.get v "from"; to_ = Jv.Int.get v "to" }

module SearchCursor = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let cls = lazy (Jv.get (Lazy.force pkg) "SearchCursor")

  let create ?from ?to_ ?normalize ?test (text : Text.t) (query : string) : t =
    let normalize_jv =
      match normalize with
      | None -> Jv.undefined
      | Some f ->
          Jv.callback ~arity:1 (fun (s : Jv.t) ->
              Jv.of_string (f (Jv.to_string s)))
    in
    let test_jv =
      match test with
      | None -> Jv.undefined
      | Some f ->
          Jv.callback ~arity:4
            (fun
              (from : Jv.t) (to_ : Jv.t) (buffer : Jv.t) (buffer_pos : Jv.t) ->
              Jv.of_bool
                (f ~from:(Jv.to_int from) ~to_:(Jv.to_int to_)
                   ~buffer:(Jv.to_string buffer)
                   ~buffer_pos:(Jv.to_int buffer_pos)))
    in
    Jv.new' (Lazy.force cls)
      [|
        Text.to_jv text;
        Jv.of_string query;
        opt_int from;
        opt_int to_;
        normalize_jv;
        test_jv;
      |]

  let next (t : t) : match_ option =
    let r = Jv.It.next t in
    if Jv.It.result_done r then None
    else Some (match_of_jv (Jv.It.get_result_value r))

  let next_overlapping (t : t) : match_ option =
    let r = Jv.call t "nextOverlapping" [||] in
    if Jv.It.result_done r then None
    else Some (match_of_jv (Jv.It.get_result_value r))

  let fold (t : t) ~(init : 'a) (f : match_ -> 'a -> 'a) : 'a =
    Jv.It.fold match_of_jv f t init

  let iter (t : t) (f : match_ -> unit) : unit =
    Jv.It.fold match_of_jv (fun m () -> f m) t ()
end

type regexp_match = { from : int; to_ : int; captures : string option array }

let captures_of_jv (arr : Jv.t) : string option array =
  Jv.to_array
    (fun v -> if Jv.is_none v then None else Some (Jv.to_string v))
    arr

let regexp_match_of_jv (v : Jv.t) : regexp_match =
  {
    from = Jv.Int.get v "from";
    to_ = Jv.Int.get v "to";
    captures = captures_of_jv (Jv.get v "match");
  }

module RegExpCursor = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let cls = lazy (Jv.get (Lazy.force pkg) "RegExpCursor")

  let create ?ignore_case ?test ?from ?to_ (text : Text.t) (query : string) : t
      =
    let options =
      match (ignore_case, test) with
      | None, None -> Jv.undefined
      | _ ->
          let o = Jv.obj [||] in
          Jv.Bool.set_if_some o "ignoreCase" ignore_case;
          Option.iter
            (fun f ->
              Jv.set o "test"
                (Jv.callback ~arity:3
                   (fun (from : Jv.t) (to_ : Jv.t) (m : Jv.t) ->
                     Jv.of_bool
                       (f ~from:(Jv.to_int from) ~to_:(Jv.to_int to_)
                          ~captures:(captures_of_jv m)))))
            test;
          o
    in
    Jv.new' (Lazy.force cls)
      [|
        Text.to_jv text; Jv.of_string query; options; opt_int from; opt_int to_;
      |]

  let next (t : t) : regexp_match option =
    let r = Jv.It.next t in
    if Jv.It.result_done r then None
    else Some (regexp_match_of_jv (Jv.It.get_result_value r))

  let fold (t : t) ~(init : 'a) (f : regexp_match -> 'a -> 'a) : 'a =
    Jv.It.fold regexp_match_of_jv f t init

  let iter (t : t) (f : regexp_match -> unit) : unit =
    Jv.It.fold regexp_match_of_jv (fun m () -> f m) t ()
end

let goto_line : command = command_of_jv (Jv.get (Lazy.force pkg) "gotoLine")

let highlight_selection_matches ?highlight_word_around_cursor
    ?min_selection_length ?max_matches ?whole_words () : Extension.t =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "highlightWordAroundCursor" highlight_word_around_cursor;
  Jv.Int.set_if_some o "minSelectionLength" min_selection_length;
  Jv.Int.set_if_some o "maxMatches" max_matches;
  Jv.Bool.set_if_some o "wholeWords" whole_words;
  Extension.of_jv (Jv.call (Lazy.force pkg) "highlightSelectionMatches" [| o |])

let select_next_occurrence : command =
  command_of_jv (Jv.get (Lazy.force pkg) "selectNextOccurrence")

let search ?top ?case_sensitive ?literal ?whole_word ?regexp ?create_panel
    ?scroll_to_match () : Extension.t =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "top" top;
  Jv.Bool.set_if_some o "caseSensitive" case_sensitive;
  Jv.Bool.set_if_some o "literal" literal;
  Jv.Bool.set_if_some o "wholeWord" whole_word;
  Jv.Bool.set_if_some o "regexp" regexp;
  Option.iter
    (fun f ->
      Jv.set o "createPanel"
        (Jv.callback ~arity:1 (fun (view : Jv.t) ->
             Panel.to_jv (f (EditorView.of_jv view)))))
    create_panel;
  Option.iter
    (fun f ->
      Jv.set o "scrollToMatch"
        (Jv.callback ~arity:2 (fun (range : Jv.t) (view : Jv.t) ->
             StateEffect.to_jv
               (f (SelectionRange.of_jv range) (EditorView.of_jv view)))))
    scroll_to_match;
  Extension.of_jv (Jv.call (Lazy.force pkg) "search" [| o |])

module SearchQuery = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let cls = lazy (Jv.get (Lazy.force pkg) "SearchQuery")

  let create ~search ?case_sensitive ?literal ?regexp ?replace ?whole_word () :
      t =
    let o = Jv.obj [||] in
    Jv.set o "search" (Jv.of_string search);
    Jv.Bool.set_if_some o "caseSensitive" case_sensitive;
    Jv.Bool.set_if_some o "literal" literal;
    Jv.Bool.set_if_some o "regexp" regexp;
    Jv.set_if_some o "replace" (Option.map Jv.of_string replace);
    Jv.Bool.set_if_some o "wholeWord" whole_word;
    Jv.new' (Lazy.force cls) [| o |]

  let search (t : t) : string = Jv.to_string (Jv.get t "search")
  let case_sensitive (t : t) : bool = Jv.Bool.get t "caseSensitive"
  let literal (t : t) : bool = Jv.Bool.get t "literal"
  let regexp (t : t) : bool = Jv.Bool.get t "regexp"
  let replace (t : t) : string = Jv.to_string (Jv.get t "replace")
  let valid (t : t) : bool = Jv.Bool.get t "valid"
  let whole_word (t : t) : bool = Jv.Bool.get t "wholeWord"
  let eq (t : t) (other : t) : bool = Jv.call t "eq" [| other |] |> Jv.to_bool

  let get_cursor (t : t) ?from ?to_
      (target : [ `State of EditorState.t | `Doc of Text.t ]) : SearchCursor.t =
    let target_jv =
      match target with
      | `State s -> EditorState.to_jv s
      | `Doc d -> Text.to_jv d
    in
    Jv.call t "getCursor" [| target_jv; opt_int from; opt_int to_ |]
end

let set_search_query : SearchQuery.t StateEffectType.t =
  StateEffectType.of_jv SearchQuery.conv
    (Jv.get (Lazy.force pkg) "setSearchQuery")

let get_search_query (state : EditorState.t) : SearchQuery.t =
  Jv.call (Lazy.force pkg) "getSearchQuery" [| EditorState.to_jv state |]

let search_panel_open (state : EditorState.t) : bool =
  Jv.call (Lazy.force pkg) "searchPanelOpen" [| EditorState.to_jv state |]
  |> Jv.to_bool

let find_next : command = command_of_jv (Jv.get (Lazy.force pkg) "findNext")

let find_previous : command =
  command_of_jv (Jv.get (Lazy.force pkg) "findPrevious")

let select_matches : command =
  command_of_jv (Jv.get (Lazy.force pkg) "selectMatches")

let select_selection_matches : command =
  command_of_jv (Jv.get (Lazy.force pkg) "selectSelectionMatches")

let replace_next : command =
  command_of_jv (Jv.get (Lazy.force pkg) "replaceNext")

let replace_all : command = command_of_jv (Jv.get (Lazy.force pkg) "replaceAll")

let open_search_panel : command =
  command_of_jv (Jv.get (Lazy.force pkg) "openSearchPanel")

let close_search_panel : command =
  command_of_jv (Jv.get (Lazy.force pkg) "closeSearchPanel")

let search_keymap : KeyBinding.t list =
  Jv.to_list KeyBinding.of_jv (Jv.get (Lazy.force pkg) "searchKeymap")
