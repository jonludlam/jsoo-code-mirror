open Cm_state
open Cm_view

let pkg = lazy (Jv.get Jv.global "__CM__autocomplete")

(* A raw exported Command/StateCommand value, called against an editor_view
   the way CodeMirror itself calls it; see src/search/cm_search.ml's
   [command_of_jv], which this copies verbatim. *)
let command_of_jv (raw : Jv.t) : command =
 fun (view : editor_view) ->
  Jv.apply raw [| EditorView.to_jv view |] |> Jv.to_bool

(* [KeyBinding] has no [conv] of its own (see Cm_view.mli); build one locally
   from its [Jv.CONV] pair, the way [Facet.of_jv] needs. *)
let keybinding_conv : KeyBinding.t Conv.t =
  Conv.{ to_jv = KeyBinding.to_jv; of_jv = KeyBinding.of_jv }

module Completion = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  module Section = struct
    type t = Jv.t

    include (Jv.Id : Jv.CONV with type t := t)

    let conv = Conv.{ to_jv; of_jv }

    let make ?rank name =
      let o = Jv.obj [||] in
      Jv.Jstr.set o "name" (Jstr.v name);
      Jv.Int.set_if_some o "rank" rank;
      o

    let name t = Jv.Jstr.get t "name" |> Jstr.to_string
    let rank t = Jv.Int.find t "rank"
  end

  let create ~label ?display_label ?detail ?info ?apply ?type_ ?boost ?section
      ?commit_characters () : t =
    let o = Jv.obj [||] in
    Jv.Jstr.set o "label" (Jstr.v label);
    Jv.Jstr.set_if_some o "displayLabel" (Option.map Jstr.v display_label);
    Jv.Jstr.set_if_some o "detail" (Option.map Jstr.v detail);
    Option.iter
      (fun info ->
        match info with
        | `Text s -> Jv.set o "info" (Jv.of_string s)
        | `Render f ->
            Jv.set o "info"
              (Jv.callback ~arity:1 (fun (c : Jv.t) -> Brr.El.to_jv (f c))))
      info;
    Option.iter
      (fun apply ->
        match apply with
        | `Text s -> Jv.set o "apply" (Jv.of_string s)
        | `Apply f ->
            Jv.set o "apply"
              (Jv.callback ~arity:4
                 (fun (view : Jv.t) (c : Jv.t) (from : Jv.t) (to_ : Jv.t) ->
                   f (EditorView.of_jv view) c ~from:(Jv.to_int from)
                     ~to_:(Jv.to_int to_))))
      apply;
    Jv.Jstr.set_if_some o "type" (Option.map Jstr.v type_);
    Jv.Int.set_if_some o "boost" boost;
    Option.iter
      (fun section ->
        match section with
        | `Name n -> Jv.set o "section" (Jv.of_string n)
        | `Section s -> Jv.set o "section" s)
      section;
    Option.iter
      (fun l -> Jv.set o "commitCharacters" (Jv.of_list Jv.of_string l))
      commit_characters;
    o

  let label t = Jv.Jstr.get t "label" |> Jstr.to_string

  let display_label t =
    Jv.Jstr.find t "displayLabel" |> Option.map Jstr.to_string

  let detail t = Jv.Jstr.find t "detail" |> Option.map Jstr.to_string
  let type_ t = Jv.Jstr.find t "type" |> Option.map Jstr.to_string
  let boost t = Jv.Int.find t "boost"

  let commit_characters t =
    Jv.find t "commitCharacters" |> Option.map (Jv.to_list Jv.to_string)
end

module CompletionContext = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let cls = lazy (Jv.get (Lazy.force pkg) "CompletionContext")

  let create (st : EditorState.t) ~pos ~explicit ?view () : t =
    let args =
      [|
        EditorState.to_jv st;
        Jv.of_int pos;
        Jv.of_bool explicit;
        Jv.of_option ~none:Jv.undefined EditorView.to_jv view;
      |]
    in
    Jv.new' (Lazy.force cls) args

  let state t = Jv.get t "state" |> EditorState.of_jv
  let pos t = Jv.Int.get t "pos"
  let explicit t = Jv.Bool.get t "explicit"
  let view t = Jv.find t "view" |> Option.map EditorView.of_jv

  type token = {
    from : int;
    to_ : int;
    text : string;
    type_ : Cm_language.NodeType.t;
  }

  let token_before t types =
    let r = Jv.call t "tokenBefore" [| Jv.of_list Jv.of_string types |] in
    if Jv.is_none r then None
    else
      Some
        {
          from = Jv.Int.get r "from";
          to_ = Jv.Int.get r "to";
          text = Jv.Jstr.get r "text" |> Jstr.to_string;
          type_ = Jv.get r "type" |> Cm_language.NodeType.of_jv;
        }

  type match_ = { from : int; to_ : int; text : string }

  let match_before t (expr : Jv.t) =
    let r = Jv.call t "matchBefore" [| expr |] in
    if Jv.is_none r then None
    else
      Some
        {
          from = Jv.Int.get r "from";
          to_ = Jv.Int.get r "to";
          text = Jv.Jstr.get r "text" |> Jstr.to_string;
        }

  let aborted t = Jv.Bool.get t "aborted"

  let add_event_listener ?on_doc_change t (f : unit -> unit) =
    let listener = Jv.callback ~arity:1 (fun (_ : Jv.t) -> f ()) in
    let opts =
      match on_doc_change with
      | None -> Jv.undefined
      | Some b -> Jv.obj [| ("onDocChange", Jv.of_bool b) |]
    in
    Jv.call t "addEventListener" [| Jv.of_string "abort"; listener; opts |]
    |> ignore
end

module CompletionResult = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ~from ?to_ ~options ?valid_for ?filter ?get_match ?update ?map
      ?commit_characters () : t =
    let o = Jv.obj [||] in
    Jv.Int.set o "from" from;
    Jv.Int.set_if_some o "to" to_;
    Jv.set o "options" (Jv.of_list Completion.to_jv options);
    Option.iter
      (fun valid_for ->
        match valid_for with
        | `Regexp re -> Jv.set o "validFor" re
        | `Predicate f ->
            Jv.set o "validFor"
              (Jv.callback ~arity:4
                 (fun (text : Jv.t) (from : Jv.t) (to_ : Jv.t) (st : Jv.t) ->
                   Jv.of_bool
                     (f (Jv.to_string text) ~from:(Jv.to_int from)
                        ~to_:(Jv.to_int to_) (EditorState.of_jv st)))))
      valid_for;
    Jv.Bool.set_if_some o "filter" filter;
    Option.iter
      (fun f ->
        Jv.set o "getMatch"
          (Jv.callback ~arity:2 (fun (c : Jv.t) (matched : Jv.t) ->
               let matched =
                 if Jv.is_none matched then None
                 else Some (Jv.to_list Jv.to_int matched)
               in
               Jv.of_list Jv.of_int (f c ?matched ()))))
      get_match;
    Option.iter
      (fun f ->
        Jv.set o "update"
          (Jv.callback ~arity:4
             (fun (current : Jv.t) (from : Jv.t) (to_ : Jv.t) (ctx : Jv.t) ->
               match
                 f current ~from:(Jv.to_int from) ~to_:(Jv.to_int to_)
                   (CompletionContext.of_jv ctx)
               with
               | None -> Jv.null
               | Some r -> r)))
      update;
    Option.iter
      (fun f ->
        Jv.set o "map"
          (Jv.callback ~arity:2 (fun (current : Jv.t) (changes : Jv.t) ->
               match f current (ChangeDesc.of_jv changes) with
               | None -> Jv.null
               | Some r -> r)))
      map;
    Option.iter
      (fun l -> Jv.set o "commitCharacters" (Jv.of_list Jv.of_string l))
      commit_characters;
    o

  let from t = Jv.Int.get t "from"
  let to_ t = Jv.Int.find t "to"
  let options t = Jv.get t "options" |> Jv.to_list Completion.of_jv
  let filter t = Jv.Bool.find t "filter"

  let commit_characters t =
    Jv.find t "commitCharacters" |> Option.map (Jv.to_list Jv.to_string)
end

type completion_source = CompletionContext.t -> CompletionResult.t option Fut.t

(* The shared "wrap an OCaml ['a -> 'b option Fut.t] as a JavaScript
   promise-returning function" pattern; see src/view/cm_view.ml's
   [hover_tooltip] and src/lint/cm_lint.ml's [linter], which this copies. *)
let source_to_jv (src : completion_source) : Jv.t =
  let wrapped (ctx : Jv.t) =
    let fut = src (CompletionContext.of_jv ctx) in
    fut
    |> Async.promise_of_fut (function
         | None -> Jv.null
         | Some r -> CompletionResult.to_jv r)
  in
  Jv.callback ~arity:1 wrapped

(* The library's own sources (below) may return their result synchronously
   or as a promise (JavaScript's [CompletionResult | null |
   Promise<CompletionResult | null>]); [Jv.Promise.resolve] normalizes
   either into a real promise (it "joins" a promise argument instead of
   wrapping it a second time, per its own doc comment), so there is no need
   to branch on which one came back. *)
let source_of_jv (raw : Jv.t) : completion_source =
 fun ctx ->
  let r = Jv.apply raw [| CompletionContext.to_jv ctx |] in
  Fut.of_promise
    ~ok:(fun v ->
      if Jv.is_none v then None else Some (CompletionResult.of_jv v))
    (Jv.Promise.resolve r)
  |> Fut.map (function Ok v -> v | Error _ -> None)

let completion_source_conv = Conv.{ to_jv = source_to_jv; of_jv = source_of_jv }

let complete_from_list (l : Completion.t list) : completion_source =
  Jv.call (Lazy.force pkg) "completeFromList"
    [| Jv.of_list Completion.to_jv l |]
  |> source_of_jv

let complete_any_word : completion_source =
  source_of_jv (Jv.get (Lazy.force pkg) "completeAnyWord")

let if_in (nodes : string list) (src : completion_source) : completion_source =
  Jv.call (Lazy.force pkg) "ifIn"
    [| Jv.of_list Jv.of_string nodes; source_to_jv src |]
  |> source_of_jv

let if_not_in (nodes : string list) (src : completion_source) :
    completion_source =
  Jv.call (Lazy.force pkg) "ifNotIn"
    [| Jv.of_list Jv.of_string nodes; source_to_jv src |]
  |> source_of_jv

let insert_completion_text (st : EditorState.t) ~text ~from ~to_ :
    TransactionSpec.t =
  Jv.call (Lazy.force pkg) "insertCompletionText"
    [| EditorState.to_jv st; Jv.of_string text; Jv.of_int from; Jv.of_int to_ |]
  |> TransactionSpec.of_jv

let picked_completion : Completion.t AnnotationType.t =
  AnnotationType.of_jv Completion.conv
    (Jv.get (Lazy.force pkg) "pickedCompletion")

type add_to_option = {
  render : Completion.t -> EditorState.t -> EditorView.t -> Brr.El.t option;
  position : int;
}

type position_info_result = { style : string option; class_ : string option }

let autocompletion ?activate_on_typing ?activate_on_completion
    ?activate_on_typing_delay ?select_on_open ?override ?close_on_blur
    ?max_rendered_options ?default_keymap ?above_cursor ?tooltip_class
    ?option_class ?icons ?add_to_options ?position_info ?compare_completions
    ?filter_strict ?interaction_delay ?update_sync_time () : Extension.t =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "activateOnTyping" activate_on_typing;
  Option.iter
    (fun f ->
      Jv.set o "activateOnCompletion"
        (Jv.callback ~arity:1 (fun (c : Jv.t) -> Jv.of_bool (f c))))
    activate_on_completion;
  Jv.Int.set_if_some o "activateOnTypingDelay" activate_on_typing_delay;
  Jv.Bool.set_if_some o "selectOnOpen" select_on_open;
  Option.iter
    (fun l -> Jv.set o "override" (Jv.of_list source_to_jv l))
    override;
  Jv.Bool.set_if_some o "closeOnBlur" close_on_blur;
  Jv.Int.set_if_some o "maxRenderedOptions" max_rendered_options;
  Jv.Bool.set_if_some o "defaultKeymap" default_keymap;
  Jv.Bool.set_if_some o "aboveCursor" above_cursor;
  Option.iter
    (fun f ->
      Jv.set o "tooltipClass"
        (Jv.callback ~arity:1 (fun (st : Jv.t) ->
             Jv.of_string (f (EditorState.of_jv st)))))
    tooltip_class;
  Option.iter
    (fun f ->
      Jv.set o "optionClass"
        (Jv.callback ~arity:1 (fun (c : Jv.t) -> Jv.of_string (f c))))
    option_class;
  Jv.Bool.set_if_some o "icons" icons;
  Option.iter
    (fun l ->
      Jv.set o "addToOptions"
        (Jv.of_list
           (fun { render; position } ->
             Jv.obj
               [|
                 ( "render",
                   Jv.callback ~arity:3
                     (fun (c : Jv.t) (st : Jv.t) (view : Jv.t) ->
                       match
                         render c (EditorState.of_jv st) (EditorView.of_jv view)
                       with
                       | None -> Jv.null
                       | Some el -> Brr.El.to_jv el) );
                 ("position", Jv.of_int position);
               |])
           l))
    add_to_options;
  Option.iter
    (fun f ->
      Jv.set o "positionInfo"
        (Jv.callback ~arity:5
           (fun
             (view : Jv.t)
             (list : Jv.t)
             (opt : Jv.t)
             (info : Jv.t)
             (space : Jv.t)
           ->
             let r =
               f (EditorView.of_jv view) ~list:(Rect.of_jv list)
                 ~option:(Rect.of_jv opt) ~info:(Rect.of_jv info)
                 ~space:(Rect.of_jv space)
             in
             let o = Jv.obj [||] in
             Jv.Jstr.set_if_some o "style" (Option.map Jstr.v r.style);
             Jv.Jstr.set_if_some o "class" (Option.map Jstr.v r.class_);
             o)))
    position_info;
  Option.iter
    (fun f ->
      Jv.set o "compareCompletions"
        (Jv.callback ~arity:2 (fun (a : Jv.t) (b : Jv.t) -> Jv.of_int (f a b))))
    compare_completions;
  Jv.Bool.set_if_some o "filterStrict" filter_strict;
  Jv.Int.set_if_some o "interactionDelay" interaction_delay;
  Jv.Int.set_if_some o "updateSyncTime" update_sync_time;
  Extension.of_jv (Jv.call (Lazy.force pkg) "autocompletion" [| o |])

let completion_keymap : KeyBinding.t list =
  Jv.get (Lazy.force pkg) "completionKeymap" |> Jv.to_list KeyBinding.of_jv

let move_completion_selection ~forward ?by () : command =
  let by_jv =
    match by with
    | None -> Jv.undefined
    | Some `Option -> Jv.of_string "option"
    | Some `Page -> Jv.of_string "page"
  in
  let raw =
    Jv.call (Lazy.force pkg) "moveCompletionSelection"
      [| Jv.of_bool forward; by_jv |]
  in
  command_of_jv raw

let accept_completion : command =
  command_of_jv (Jv.get (Lazy.force pkg) "acceptCompletion")

let start_completion : command =
  command_of_jv (Jv.get (Lazy.force pkg) "startCompletion")

let close_completion : command =
  command_of_jv (Jv.get (Lazy.force pkg) "closeCompletion")

let completion_status (st : EditorState.t) : [ `Active | `Pending ] option =
  let r =
    Jv.call (Lazy.force pkg) "completionStatus" [| EditorState.to_jv st |]
  in
  if Jv.is_null r then None
  else
    match Jv.to_string r with
    | "active" -> Some `Active
    | "pending" -> Some `Pending
    | s -> Conv.invalid "completion_status" (Jv.of_string s)

let current_completions (st : EditorState.t) : Completion.t list =
  Jv.call (Lazy.force pkg) "currentCompletions" [| EditorState.to_jv st |]
  |> Jv.to_list Completion.of_jv

let selected_completion (st : EditorState.t) : Completion.t option =
  let r =
    Jv.call (Lazy.force pkg) "selectedCompletion" [| EditorState.to_jv st |]
  in
  if Jv.is_null r then None else Some r

let selected_completion_index (st : EditorState.t) : int option =
  let r =
    Jv.call (Lazy.force pkg) "selectedCompletionIndex"
      [| EditorState.to_jv st |]
  in
  if Jv.is_null r then None else Some (Jv.to_int r)

let set_selected_completion (index : int) : StateEffect.t =
  Jv.call (Lazy.force pkg) "setSelectedCompletion" [| Jv.of_int index |]
  |> StateEffect.of_jv

module CloseBracketConfig = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ?brackets ?before ?string_prefixes () : t =
    let o = Jv.obj [||] in
    Option.iter
      (fun l -> Jv.set o "brackets" (Jv.of_list Jv.of_string l))
      brackets;
    Jv.Jstr.set_if_some o "before" (Option.map Jstr.v before);
    Option.iter
      (fun l -> Jv.set o "stringPrefixes" (Jv.of_list Jv.of_string l))
      string_prefixes;
    o
end

let close_brackets () : Extension.t =
  Extension.of_jv (Jv.call (Lazy.force pkg) "closeBrackets" [||])

let close_brackets_keymap : KeyBinding.t list =
  Jv.get (Lazy.force pkg) "closeBracketsKeymap" |> Jv.to_list KeyBinding.of_jv

let delete_bracket_pair : command =
  command_of_jv (Jv.get (Lazy.force pkg) "deleteBracketPair")

let insert_bracket (st : EditorState.t) ~bracket : Transaction.t option =
  let r =
    Jv.call (Lazy.force pkg) "insertBracket"
      [| EditorState.to_jv st; Jv.of_string bracket |]
  in
  if Jv.is_null r then None else Some (Transaction.of_jv r)

let snippet (template : string) :
    EditorView.t -> Completion.t option -> from:int -> to_:int -> unit =
  let f = Jv.call (Lazy.force pkg) "snippet" [| Jv.of_string template |] in
  fun (view : EditorView.t) (completion : Completion.t option) ~from ~to_ ->
    Jv.apply f
      [|
        EditorView.to_jv view;
        Jv.of_option ~none:Jv.null Fun.id completion;
        Jv.of_int from;
        Jv.of_int to_;
      |]
    |> ignore

let snippet_completion ~template (c : Completion.t) : Completion.t =
  Jv.call (Lazy.force pkg) "snippetCompletion" [| Jv.of_string template; c |]

let snippet_keymap : (KeyBinding.t list, KeyBinding.t list) Facet.t =
  Facet.of_jv
    (Conv.list keybinding_conv)
    (Conv.list keybinding_conv)
    (Jv.get (Lazy.force pkg) "snippetKeymap")

let clear_snippet : command =
  command_of_jv (Jv.get (Lazy.force pkg) "clearSnippet")

let next_snippet_field : command =
  command_of_jv (Jv.get (Lazy.force pkg) "nextSnippetField")

let prev_snippet_field : command =
  command_of_jv (Jv.get (Lazy.force pkg) "prevSnippetField")

let has_next_snippet_field (st : EditorState.t) : bool =
  Jv.call (Lazy.force pkg) "hasNextSnippetField" [| EditorState.to_jv st |]
  |> Jv.to_bool

let has_prev_snippet_field (st : EditorState.t) : bool =
  Jv.call (Lazy.force pkg) "hasPrevSnippetField" [| EditorState.to_jv st |]
  |> Jv.to_bool
