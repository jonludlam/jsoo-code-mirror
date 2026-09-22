open Cm_state

(* Forward declarations, equated inside the modules below. *)
type language = Jv.t
type tree = Jv.t
type syntax_node = Jv.t
type node_type = Jv.t
type indent_context = Jv.t

let pkg = lazy (Jv.get Jv.global "__CM__language")
let lezer_common = lazy (Jv.get Jv.global "__CM__lezer_common")
let lezer_highlight = lazy (Jv.get Jv.global "__CM__lezer_highlight")
let object_cls = lazy (Jv.get Jv.global "Object")
let node_type_cls = lazy (Jv.get (Lazy.force lezer_common) "NodeType")
let tree_cls = lazy (Jv.get (Lazy.force lezer_common) "Tree")
let tag_cls = lazy (Jv.get (Lazy.force lezer_highlight) "Tag")
let language_cls = lazy (Jv.get (Lazy.force pkg) "Language")
let lr_language_cls = lazy (Jv.get (Lazy.force pkg) "LRLanguage")
let language_support_cls = lazy (Jv.get (Lazy.force pkg) "LanguageSupport")

let language_description_cls =
  lazy (Jv.get (Lazy.force pkg) "LanguageDescription")

let indent_context_cls = lazy (Jv.get (Lazy.force pkg) "IndentContext")
let stream_language_cls = lazy (Jv.get (Lazy.force pkg) "StreamLanguage")
let highlight_style_cls = lazy (Jv.get (Lazy.force pkg) "HighlightStyle")

(* Small helpers: an absent optional argument becomes [undefined], relying
   on JavaScript's own default parameters. *)
let opt_int = Jv.of_option ~none:Jv.undefined Jv.of_int
let opt_str = Jv.of_option ~none:Jv.undefined Jv.of_string
let opt_bool = Jv.of_option ~none:Jv.undefined Jv.of_bool
let opt_jv = Jv.of_option ~none:Jv.undefined Fun.id

(* [LanguageDescription.load] hands us a JavaScript promise; the rest of
   this binding only ever hands JavaScript a [Fut.t] (as in Cm_view's
   [hover_tooltip]), so this is the one place a promise flows the other
   way. Rejections are dropped: the future simply never determines, which
   matches this binding's simplified (non-[result]) [Fut.t] signature. *)
let fut_of_promise = Async.fut_of_promise
let promise_of_fut = Async.promise_of_fut

module NodeProp = struct
  type t = Jv.t

  let cls = lazy (Jv.get (Lazy.force lezer_common) "NodeProp")
  let closed_by = Jv.get (Lazy.force cls) "closedBy"
  let opened_by = Jv.get (Lazy.force cls) "openedBy"
  let group = Jv.get (Lazy.force cls) "group"
  let isolate = Jv.get (Lazy.force cls) "isolate"
  let context_hash = Jv.get (Lazy.force cls) "contextHash"
  let look_ahead = Jv.get (Lazy.force cls) "lookAhead"
  let mounted = Jv.get (Lazy.force cls) "mounted"
  let language_data = Jv.get (Lazy.force pkg) "languageDataProp"
  let sublanguage = Jv.get (Lazy.force pkg) "sublanguageProp"
  let fold = Jv.get (Lazy.force pkg) "foldNodeProp"
  let indent = Jv.get (Lazy.force pkg) "indentNodeProp"
  let bracket_matching_handle = Jv.get (Lazy.force pkg) "bracketMatchingHandle"
end

let language_data_prop = NodeProp.language_data
let sublanguage_prop = NodeProp.sublanguage
let fold_node_prop = NodeProp.fold
let indent_node_prop = NodeProp.indent
let bracket_matching_handle = NodeProp.bracket_matching_handle

module NodeType = struct
  type t = node_type

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let name t = Jv.Jstr.get t "name" |> Jstr.to_string
  let id t = Jv.Int.get t "id"
  let is_top t = Jv.Bool.get t "isTop"
  let is_skipped t = Jv.Bool.get t "isSkipped"
  let is_error t = Jv.Bool.get t "isError"
  let is_anonymous t = Jv.Bool.get t "isAnonymous"
  let is t name = Jv.call t "is" [| Jv.of_string name |] |> Jv.to_bool
  let none = Jv.get (Lazy.force node_type_cls) "none"

  let prop t (p : NodeProp.t) =
    let r = Jv.call t "prop" [| p |] in
    if Jv.is_undefined r then None else Some r

  let closed_by_names t =
    match prop t NodeProp.closed_by with
    | Some v -> Jv.to_list Jv.to_string v
    | None -> []

  let opened_by_names t =
    match prop t NodeProp.opened_by with
    | Some v -> Jv.to_list Jv.to_string v
    | None -> []

  let group_names t =
    match prop t NodeProp.group with
    | Some v -> Jv.to_list Jv.to_string v
    | None -> []

  let is_isolate t =
    match prop t NodeProp.isolate with
    | None -> None
    | Some v -> (
        match Jv.to_string v with
        | "rtl" -> Some `Rtl
        | "ltr" -> Some `Ltr
        | "auto" -> Some `Auto
        | s -> Conv.invalid "NodeType.is_isolate" (Jv.of_string s))
end

module Tree = struct
  type t = tree

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let type_ t : node_type = Jv.get t "type"
  let length t = Jv.Int.get t "length"
  let top_node t : syntax_node = Jv.get t "topNode"

  let resolve ?side t pos : syntax_node =
    Jv.call t "resolve" [| Jv.of_int pos; opt_int side |]

  let resolve_inner ?side t pos : syntax_node =
    Jv.call t "resolveInner" [| Jv.of_int pos; opt_int side |]

  let prop t (p : NodeProp.t) =
    let r = Jv.call t "prop" [| p |] in
    if Jv.is_undefined r then None else Some r

  let iterate ?from ?to_ t ~enter ?leave () =
    let o = Jv.obj [||] in
    let enter_wrapped (n : Jv.t) = Jv.of_bool (enter (Jv.get n "node")) in
    Jv.set o "enter" (Jv.callback ~arity:1 enter_wrapped);
    Option.iter
      (fun f ->
        let leave_wrapped (n : Jv.t) =
          f (Jv.get n "node");
          Jv.undefined
        in
        Jv.set o "leave" (Jv.callback ~arity:1 leave_wrapped))
      leave;
    Jv.Int.set_if_some o "from" from;
    Jv.Int.set_if_some o "to" to_;
    Jv.call t "iterate" [| o |] |> ignore

  let empty = Jv.get (Lazy.force tree_cls) "empty"
end

module SyntaxNode = struct
  type t = syntax_node

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let name t = Jv.Jstr.get t "name" |> Jstr.to_string
  let from t = Jv.Int.get t "from"
  let to_ t = Jv.Int.get t "to"
  let type_ t : node_type = Jv.get t "type"
  let opt_node r = if Jv.is_null r then None else Some r
  let parent t = opt_node (Jv.get t "parent")
  let first_child t = opt_node (Jv.get t "firstChild")
  let last_child t = opt_node (Jv.get t "lastChild")
  let child_after t pos = opt_node (Jv.call t "childAfter" [| Jv.of_int pos |])

  let child_before t pos =
    opt_node (Jv.call t "childBefore" [| Jv.of_int pos |])

  let next_sibling t = opt_node (Jv.get t "nextSibling")
  let prev_sibling t = opt_node (Jv.get t "prevSibling")

  let resolve ?side t pos =
    Jv.call t "resolve" [| Jv.of_int pos; opt_int side |]

  let resolve_inner ?side t pos =
    Jv.call t "resolveInner" [| Jv.of_int pos; opt_int side |]

  let enter ?mode t ~pos ~side =
    opt_node
      (Jv.call t "enter" [| Jv.of_int pos; Jv.of_int side; opt_int mode |])

  let get_child t name = opt_node (Jv.call t "getChild" [| Jv.of_string name |])

  let get_children t name =
    Jv.call t "getChildren" [| Jv.of_string name |] |> Jv.to_list Fun.id

  let to_tree t : tree = Jv.call t "toTree" [||]

  let match_context t ctx =
    Jv.call t "matchContext" [| Jv.of_list Jv.of_string ctx |] |> Jv.to_bool
end

module Parser = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let parse t (s : string) : tree = Jv.call t "parse" [| Jv.of_string s |]
end

module Tag = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let define ?name ?parent () : t =
    Jv.call (Lazy.force tag_cls) "define" [| opt_str name; opt_jv parent |]

  let define_modifier ?name () : t -> t =
    let f = Jv.call (Lazy.force tag_cls) "defineModifier" [| opt_str name |] in
    fun (tag : t) -> Jv.apply f [| tag |]

  let set t = Jv.get t "set" |> Jv.to_list Fun.id
end

module Tags = struct
  let tags_obj = lazy (Jv.get (Lazy.force lezer_highlight) "tags")
  let g name : Tag.t = Jv.get (Lazy.force tags_obj) name
  let comment = g "comment"
  let line_comment = g "lineComment"
  let block_comment = g "blockComment"
  let doc_comment = g "docComment"
  let name = g "name"
  let variable_name = g "variableName"
  let type_name = g "typeName"
  let tag_name = g "tagName"
  let property_name = g "propertyName"
  let attribute_name = g "attributeName"
  let class_name = g "className"
  let label_name = g "labelName"
  let namespace = g "namespace"
  let macro_name = g "macroName"
  let literal = g "literal"
  let string = g "string"
  let doc_string = g "docString"
  let character = g "character"
  let attribute_value = g "attributeValue"
  let number = g "number"
  let integer = g "integer"
  let float = g "float"
  let bool = g "bool"
  let regexp = g "regexp"
  let escape = g "escape"
  let color = g "color"
  let url = g "url"
  let keyword = g "keyword"
  let self = g "self"
  let null_ = g "null"
  let atom = g "atom"
  let unit = g "unit"
  let modifier = g "modifier"
  let operator_keyword = g "operatorKeyword"
  let control_keyword = g "controlKeyword"
  let definition_keyword = g "definitionKeyword"
  let module_keyword = g "moduleKeyword"
  let operator = g "operator"
  let deref_operator = g "derefOperator"
  let arithmetic_operator = g "arithmeticOperator"
  let logic_operator = g "logicOperator"
  let bitwise_operator = g "bitwiseOperator"
  let compare_operator = g "compareOperator"
  let update_operator = g "updateOperator"
  let definition_operator = g "definitionOperator"
  let type_operator = g "typeOperator"
  let control_operator = g "controlOperator"
  let punctuation = g "punctuation"
  let separator = g "separator"
  let bracket = g "bracket"
  let angle_bracket = g "angleBracket"
  let square_bracket = g "squareBracket"
  let paren = g "paren"
  let brace = g "brace"
  let content = g "content"
  let heading = g "heading"
  let heading1 = g "heading1"
  let heading2 = g "heading2"
  let heading3 = g "heading3"
  let heading4 = g "heading4"
  let heading5 = g "heading5"
  let heading6 = g "heading6"
  let content_separator = g "contentSeparator"
  let list = g "list"
  let quote = g "quote"
  let emphasis = g "emphasis"
  let strong = g "strong"
  let link = g "link"
  let monospace = g "monospace"
  let strikethrough = g "strikethrough"
  let inserted = g "inserted"
  let deleted = g "deleted"
  let changed = g "changed"
  let invalid = g "invalid"
  let meta = g "meta"
  let document_meta = g "documentMeta"
  let annotation = g "annotation"
  let processing_instruction = g "processingInstruction"

  let modifier_fn name =
    let f = g name in
    fun (t : Tag.t) -> Jv.apply f [| t |]

  let definition = modifier_fn "definition"
  let constant = modifier_fn "constant"
  let function_ = modifier_fn "function"
  let standard = modifier_fn "standard"
  let local = modifier_fn "local"
  let special = modifier_fn "special"
end

module NodePropSource = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
end

module ParserConfig = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ?props ?top ?dialect ?strict ?buffer_length () : t =
    let o = Jv.obj [||] in
    Option.iter
      (fun l -> Jv.set o "props" (Jv.of_list NodePropSource.to_jv l))
      props;
    Jv.set_if_some o "top" (Option.map Jv.of_string top);
    Jv.set_if_some o "dialect" (Option.map Jv.of_string dialect);
    Jv.Bool.set_if_some o "strict" strict;
    Jv.Int.set_if_some o "bufferLength" buffer_length;
    o
end

module LRParser = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let to_parser (t : t) : Parser.t = t
  let configure t (cfg : ParserConfig.t) : t = Jv.call t "configure" [| cfg |]
  let has_wrappers t = Jv.call t "hasWrappers" [||] |> Jv.to_bool
  let get_name t term = Jv.call t "getName" [| Jv.of_int term |] |> Jv.to_string
  let top_node t : node_type = Jv.get t "topNode"
end

module Language = struct
  type t = language

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ~data ~parser ?extra_extensions ?name () : t =
    let extra =
      match extra_extensions with
      | None -> Jv.undefined
      | Some l -> Jv.of_list Extension.to_jv l
    in
    Jv.new' (Lazy.force language_cls)
      [| Facet.to_jv data; parser; extra; opt_str name |]

  let data t : (Jv.t, Jv.t list) Facet.t =
    Facet.of_jv Conv.jv (Conv.list Conv.jv) (Jv.get t "data")

  let name t = Jv.Jstr.get t "name" |> Jstr.to_string
  let extension t : Extension.t = Extension.of_jv (Jv.get t "extension")
  let parser t : Parser.t = Jv.get t "parser"

  let is_active_at t state ~pos ?side () =
    Jv.call t "isActiveAt"
      [| EditorState.to_jv state; Jv.of_int pos; opt_int side |]
    |> Jv.to_bool

  let find_regions t state =
    Jv.call t "findRegions" [| EditorState.to_jv state |]
    |> Jv.to_list (fun r -> (Jv.Int.get r "from", Jv.Int.get r "to"))

  let allows_nesting t = Jv.Bool.get t "allowsNesting"
end

module LRLanguage = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let to_language (t : t) : language = t

  let define ?name ~parser ?language_data () : t =
    let o = Jv.obj [||] in
    Jv.set_if_some o "name" (Option.map Jv.of_string name);
    Jv.set o "parser" parser;
    Jv.set_if_some o "languageData" language_data;
    Jv.call (Lazy.force lr_language_cls) "define" [| o |]

  let configure t ?name (cfg : ParserConfig.t) : t =
    Jv.call t "configure" [| cfg; opt_str name |]

  let parser t : LRParser.t = Jv.get t "parser"
  let allows_nesting t = Jv.Bool.get t "allowsNesting"
end

module LanguageSupport = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create (lang : language) ?support () : t =
    Jv.new'
      (Lazy.force language_support_cls)
      [| lang; opt_jv (Option.map Extension.to_jv support) |]

  let language t : language = Jv.get t "language"
  let support t : Extension.t = Extension.of_jv (Jv.get t "support")
  let extension t : Extension.t = Extension.of_jv (Jv.get t "extension")
end

module LanguageDescription = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let name t = Jv.Jstr.get t "name" |> Jstr.to_string
  let alias t = Jv.get t "alias" |> Jv.to_list Jv.to_string
  let extensions t = Jv.get t "extensions" |> Jv.to_list Jv.to_string
  let filename t = Jv.find t "filename"
  let support t = Jv.find t "support"

  let load t : LanguageSupport.t Fut.t =
    fut_of_promise Fun.id (Jv.call t "load" [||])

  let of_ ~name ?alias ?extensions ?filename ?load ?support () : t =
    let o = Jv.obj [||] in
    Jv.set o "name" (Jv.of_string name);
    Option.iter (fun l -> Jv.set o "alias" (Jv.of_list Jv.of_string l)) alias;
    Option.iter
      (fun l -> Jv.set o "extensions" (Jv.of_list Jv.of_string l))
      extensions;
    Jv.set_if_some o "filename" filename;
    Option.iter
      (fun f ->
        let wrapped (_ : Jv.t) = promise_of_fut Fun.id (f ()) in
        Jv.set o "load" (Jv.callback ~arity:1 wrapped))
      load;
    Jv.set_if_some o "support" support;
    Jv.call (Lazy.force language_description_cls) "of" [| o |]

  let match_filename descs fname =
    let r =
      Jv.call
        (Lazy.force language_description_cls)
        "matchFilename"
        [| Jv.of_list Fun.id descs; Jv.of_string fname |]
    in
    if Jv.is_null r then None else Some r

  let match_language_name ?fuzzy descs name =
    let r =
      Jv.call
        (Lazy.force language_description_cls)
        "matchLanguageName"
        [| Jv.of_list Fun.id descs; Jv.of_string name; opt_bool fuzzy |]
    in
    if Jv.is_null r then None else Some r
end

let language : (language, language option) Facet.t =
  Facet.of_jv Language.conv
    (Conv.option Language.conv)
    (Jv.get (Lazy.force pkg) "language")

let syntax_tree (state : EditorState.t) : tree =
  Jv.call (Lazy.force pkg) "syntaxTree" [| EditorState.to_jv state |]

let ensure_syntax_tree (state : EditorState.t) ~upto ?timeout () : tree option =
  let r =
    Jv.call (Lazy.force pkg) "ensureSyntaxTree"
      [| EditorState.to_jv state; Jv.of_int upto; opt_int timeout |]
  in
  if Jv.is_null r then None else Some r

let syntax_tree_available (state : EditorState.t) ?upto () : bool =
  Jv.call (Lazy.force pkg) "syntaxTreeAvailable"
    [| EditorState.to_jv state; opt_int upto |]
  |> Jv.to_bool

let force_parsing (view : Cm_view.editor_view) ?upto ?timeout () : bool =
  Jv.call (Lazy.force pkg) "forceParsing"
    [| Cm_view.EditorView.to_jv view; opt_int upto; opt_int timeout |]
  |> Jv.to_bool

let syntax_parser_running (view : Cm_view.editor_view) : bool =
  Jv.call (Lazy.force pkg) "syntaxParserRunning"
    [| Cm_view.EditorView.to_jv view |]
  |> Jv.to_bool

let language_data_of_node_type (nt : node_type) :
    (Jv.t, Jv.t list) Facet.t option =
  match NodeType.prop nt NodeProp.language_data with
  | None -> None
  | Some v -> Some (Facet.of_jv Conv.jv (Conv.list Conv.jv) v)

let define_language_facet ?base_data () : (Jv.t, Jv.t list) Facet.t =
  let jv =
    Jv.call (Lazy.force pkg) "defineLanguageFacet" [| opt_jv base_data |]
  in
  Facet.of_jv Conv.jv (Conv.list Conv.jv) jv

module IndentContext = struct
  type t = indent_context

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ?override_indentation ?simulate_break ?simulate_double_break
      (state : EditorState.t) : t =
    let opts = Jv.obj [||] in
    Option.iter
      (fun f ->
        let wrapped (p : Jv.t) = Jv.of_int (f (Jv.to_int p)) in
        Jv.set opts "overrideIndentation" (Jv.callback ~arity:1 wrapped))
      override_indentation;
    Jv.Int.set_if_some opts "simulateBreak" simulate_break;
    Jv.Bool.set_if_some opts "simulateDoubleBreak" simulate_double_break;
    Jv.new' (Lazy.force indent_context_cls) [| EditorState.to_jv state; opts |]

  let state t : EditorState.t = EditorState.of_jv (Jv.get t "state")
  let unit_ t = Jv.Int.get t "unit"

  let line_at ?bias t pos =
    let r = Jv.call t "lineAt" [| Jv.of_int pos; opt_int bias |] in
    (Jv.Jstr.get r "text" |> Jstr.to_string, Jv.Int.get r "from")

  let text_after_pos ?bias t pos =
    Jv.call t "textAfterPos" [| Jv.of_int pos; opt_int bias |] |> Jv.to_string

  let column ?bias t pos =
    Jv.call t "column" [| Jv.of_int pos; opt_int bias |] |> Jv.to_int

  let count_column ?pos t s =
    Jv.call t "countColumn" [| Jv.of_string s; opt_int pos |] |> Jv.to_int

  let line_indent ?bias t pos =
    Jv.call t "lineIndent" [| Jv.of_int pos; opt_int bias |] |> Jv.to_int

  let simulated_break t = Jv.Int.find t "simulatedBreak"
end

module TreeIndentContext = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let to_indent_context (t : t) : indent_context = t
  let node t : syntax_node = Jv.get t "node"
  let text_after t = Jv.Jstr.get t "textAfter" |> Jstr.to_string
  let base_indent t = Jv.Int.get t "baseIndent"

  let base_indent_for t (n : syntax_node) =
    Jv.call t "baseIndentFor" [| n |] |> Jv.to_int

  let continue_ t =
    let r = Jv.call t "continue" [||] in
    if Jv.is_null r then None else Some (Jv.to_int r)

  let pos t = Jv.Int.get t "pos"
end

type indent_result = [ `Indent of int | `None | `Defer ]

let indent_service : (indent_context -> pos:int -> indent_result, Jv.t) Facet.t
    =
  let in_conv : (indent_context -> pos:int -> indent_result) Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          let wrapped (ctx : Jv.t) (pos : Jv.t) =
            match f ctx ~pos:(Jv.to_int pos) with
            | `Indent n -> Jv.of_int n
            | `None -> Jv.null
            | `Defer -> Jv.undefined
          in
          Jv.callback ~arity:2 wrapped);
      of_jv = (fun _ -> Conv.invalid "indent_service" Jv.null);
    }
  in
  Facet.of_jv in_conv Conv.jv (Jv.get (Lazy.force pkg) "indentService")

let indent_unit : (string, string) Facet.t =
  Facet.of_jv Conv.string Conv.string (Jv.get (Lazy.force pkg) "indentUnit")

let get_indent_unit (state : EditorState.t) : int =
  Jv.call (Lazy.force pkg) "getIndentUnit" [| EditorState.to_jv state |]
  |> Jv.to_int

let indent_string (state : EditorState.t) (cols : int) : string =
  Jv.call (Lazy.force pkg) "indentString"
    [| EditorState.to_jv state; Jv.of_int cols |]
  |> Jv.to_string

let get_indentation
    (target : [ `State of EditorState.t | `Context of indent_context ]) ~pos :
    int option =
  let tjv =
    match target with `State s -> EditorState.to_jv s | `Context c -> c
  in
  let r = Jv.call (Lazy.force pkg) "getIndentation" [| tjv; Jv.of_int pos |] in
  if Jv.is_null r then None else Some (Jv.to_int r)

let indent_range (state : EditorState.t) ~from ~to_ : ChangeSet.t =
  ChangeSet.of_jv
    (Jv.call (Lazy.force pkg) "indentRange"
       [| EditorState.to_jv state; Jv.of_int from; Jv.of_int to_ |])

let delimited_indent ~closing ?align ?units () : TreeIndentContext.t -> int =
  let o = Jv.obj [||] in
  Jv.set o "closing" (Jv.of_string closing);
  Jv.Bool.set_if_some o "align" align;
  Jv.Int.set_if_some o "units" units;
  let f = Jv.call (Lazy.force pkg) "delimitedIndent" [| o |] in
  fun (tic : TreeIndentContext.t) -> Jv.apply f [| tic |] |> Jv.to_int

let flat_indent_fn = lazy (Jv.get (Lazy.force pkg) "flatIndent")

let flat_indent (tic : TreeIndentContext.t) : int =
  Jv.apply (Lazy.force flat_indent_fn) [| tic |] |> Jv.to_int

let continued_indent ?units () : TreeIndentContext.t -> int =
  let o = Jv.obj [||] in
  Jv.Int.set_if_some o "units" units;
  let f = Jv.call (Lazy.force pkg) "continuedIndent" [| o |] in
  fun (tic : TreeIndentContext.t) -> Jv.apply f [| tic |] |> Jv.to_int

let indent_on_input () : Extension.t =
  Extension.of_jv (Jv.call (Lazy.force pkg) "indentOnInput" [||])

module StringStream = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let string t = Jv.Jstr.get t "string" |> Jstr.to_string
  let pos t = Jv.Int.get t "pos"
  let start t = Jv.Int.get t "start"
  let indent_unit t = Jv.Int.get t "indentUnit"
  let eol t = Jv.call t "eol" [||] |> Jv.to_bool
  let sol t = Jv.call t "sol" [||] |> Jv.to_bool

  let peek t =
    let r = Jv.call t "peek" [||] in
    if Jv.is_undefined r then None else Some (Jv.to_string r)

  let next t =
    let r = Jv.call t "next" [||] in
    if Jv.is_undefined r then None else Some (Jv.to_string r)

  let pred_jv (f : string -> bool) : Jv.t =
    Jv.callback ~arity:1 (fun (ch : Jv.t) -> Jv.of_bool (f (Jv.to_string ch)))

  let eat t f =
    let r = Jv.call t "eat" [| pred_jv f |] in
    if Jv.is_undefined r then None else Some (Jv.to_string r)

  let eat_while t f = Jv.call t "eatWhile" [| pred_jv f |] |> Jv.to_bool
  let eat_space t = Jv.call t "eatSpace" [||] |> Jv.to_bool
  let skip_to_end t = Jv.call t "skipToEnd" [||] |> ignore
  let skip_to t ch = Jv.call t "skipTo" [| Jv.of_string ch |] |> Jv.to_bool
  let back_up t n = Jv.call t "backUp" [| Jv.of_int n |] |> ignore
  let column t = Jv.call t "column" [||] |> Jv.to_int
  let indentation t = Jv.call t "indentation" [||] |> Jv.to_int

  let match_ t ?consume ?case_insensitive pattern =
    Jv.call t "match"
      [| Jv.of_string pattern; opt_bool consume; opt_bool case_insensitive |]
    |> Jv.to_bool

  let current t = Jv.call t "current" [||] |> Jv.to_string
end

module StreamParser = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create (type state) ~token ?name ?start_state ?copy_state ?indent
      ?blank_line ?language_data ?token_table ?merge_tokens () : t =
    let o = Jv.obj [||] in
    let token_wrapped (stream : Jv.t) (state_jv : Jv.t) : Jv.t =
      let (st : state) = Jv.Id.of_jv state_jv in
      match token stream st with
      | None -> Jv.null
      | Some tag -> Jv.of_string tag
    in
    Jv.set o "token" (Jv.callback ~arity:2 token_wrapped);
    Jv.set_if_some o "name" (Option.map Jv.of_string name);
    (match start_state with
    | Some f ->
        let wrapped (iu : Jv.t) : Jv.t =
          Jv.Id.to_jv (f ~indent_unit:(Jv.to_int iu) : state)
        in
        Jv.set o "startState" (Jv.callback ~arity:1 wrapped)
    | None ->
        Jv.set o "startState"
          (Jv.callback ~arity:1 (fun (_ : Jv.t) -> Jv.Id.to_jv ())));
    (match copy_state with
    | Some f ->
        let wrapped (s : Jv.t) : Jv.t =
          let (st : state) = Jv.Id.of_jv s in
          Jv.Id.to_jv (f st : state)
        in
        Jv.set o "copyState" (Jv.callback ~arity:1 wrapped)
    | None -> Jv.set o "copyState" (Jv.callback ~arity:1 (fun (s : Jv.t) -> s)));
    (match indent with
    | Some f ->
        let wrapped (s : Jv.t) (text_after : Jv.t) (ctx : Jv.t) : Jv.t =
          let (st : state) = Jv.Id.of_jv s in
          match f st ~text_after:(Jv.to_string text_after) ctx with
          | None -> Jv.null
          | Some n -> Jv.of_int n
        in
        Jv.set o "indent" (Jv.callback ~arity:3 wrapped)
    | None -> ());
    (match blank_line with
    | Some f ->
        let wrapped (s : Jv.t) (iu : Jv.t) : Jv.t =
          let (st : state) = Jv.Id.of_jv s in
          f st ~indent_unit:(Jv.to_int iu);
          Jv.undefined
        in
        Jv.set o "blankLine" (Jv.callback ~arity:2 wrapped)
    | None -> ());
    Jv.set_if_some o "languageData" language_data;
    (match token_table with
    | Some pairs ->
        let tt = Jv.obj [||] in
        List.iter
          (fun (name, tags) -> Jv.set tt name (Jv.of_list Tag.to_jv tags))
          pairs;
        Jv.set o "tokenTable" tt
    | None -> ());
    Jv.Bool.set_if_some o "mergeTokens" merge_tokens;
    o
end

module StreamLanguage = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let to_language (t : t) : language = t

  let define (sp : StreamParser.t) : t =
    Jv.call (Lazy.force stream_language_cls) "define" [| sp |]

  let allows_nesting t = Jv.Bool.get t "allowsNesting"
end

module Highlighter = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
end

module TagStyle = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let make ?class_ ?style (tags : Tag.t list) : t =
    let o = Jv.obj [| ("tag", Jv.of_list Fun.id tags) |] in
    Jv.set_if_some o "class" (Option.map Jv.of_string class_);
    Option.iter
      (fun s ->
        Jv.call (Lazy.force object_cls) "assign"
          [| o; Cm_view.StyleSpec.to_jv s |]
        |> ignore)
      style;
    o
end

module HighlightStyle = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }
  let to_highlighter (t : t) : Highlighter.t = t

  let define ?scope ?all ?theme_type (specs : TagStyle.t list) : t =
    let o = Jv.obj [||] in
    Option.iter
      (fun s ->
        match s with
        | `Language l -> Jv.set o "scope" l
        | `Node_type n -> Jv.set o "scope" n)
      scope;
    Option.iter
      (fun a ->
        match a with
        | `Class c -> Jv.set o "all" (Jv.of_string c)
        | `Style st -> Jv.set o "all" (Cm_view.StyleSpec.to_jv st))
      all;
    Option.iter
      (fun tt ->
        Jv.set o "themeType"
          (Jv.of_string (match tt with `Dark -> "dark" | `Light -> "light")))
      theme_type;
    Jv.call
      (Lazy.force highlight_style_cls)
      "define"
      [| Jv.of_list Fun.id specs; o |]
end

let default_highlight_style : HighlightStyle.t =
  Jv.get (Lazy.force pkg) "defaultHighlightStyle"

let syntax_highlighting ?fallback (hs : HighlightStyle.t) : Extension.t =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "fallback" fallback;
  Extension.of_jv (Jv.call (Lazy.force pkg) "syntaxHighlighting" [| hs; o |])

let highlighting_for (state : EditorState.t) (tags : Tag.t list) ?scope () :
    string option =
  let r =
    Jv.call (Lazy.force pkg) "highlightingFor"
      [| EditorState.to_jv state; Jv.of_list Fun.id tags; opt_jv scope |]
  in
  if Jv.is_null r then None else Some (Jv.to_string r)

let style_tags (spec : (string * Tag.t list) list) : NodePropSource.t =
  let o = Jv.obj [||] in
  List.iter (fun (sel, tags) -> Jv.set o sel (Jv.of_list Fun.id tags)) spec;
  Jv.call (Lazy.force lezer_highlight) "styleTags" [| o |]

let tag_highlighter ?scope ?all (pairs : (Tag.t list * string) list) :
    Highlighter.t =
  let arr =
    Jv.of_list
      (fun (tags, cls) ->
        Jv.obj
          [| ("tag", Jv.of_list Fun.id tags); ("class", Jv.of_string cls) |])
      pairs
  in
  let o = Jv.obj [||] in
  Option.iter
    (fun f ->
      Jv.set o "scope"
        (Jv.callback ~arity:1 (fun (nt : Jv.t) -> Jv.of_bool (f nt))))
    scope;
  Jv.set_if_some o "all" (Option.map Jv.of_string all);
  Jv.call (Lazy.force lezer_highlight) "tagHighlighter" [| arr; o |]

let class_highlighter : Highlighter.t =
  Jv.get (Lazy.force lezer_highlight) "classHighlighter"

let highlight_tree ?from ?to_ (tr : tree) (hls : Highlighter.t list)
    (put_style : from:int -> to_:int -> classes:string -> unit) : unit =
  let wrapped (f : Jv.t) (t : Jv.t) (c : Jv.t) =
    put_style ~from:(Jv.to_int f) ~to_:(Jv.to_int t) ~classes:(Jv.to_string c);
    Jv.undefined
  in
  Jv.call
    (Lazy.force lezer_highlight)
    "highlightTree"
    [|
      tr;
      Jv.of_list Fun.id hls;
      Jv.callback ~arity:3 wrapped;
      opt_int from;
      opt_int to_;
    |]
  |> ignore

let highlight_code ?from ?to_ (code : string) (tr : tree)
    (hls : Highlighter.t list) ~put_text ~put_break () : unit =
  let put_text_wrapped (c : Jv.t) (cls : Jv.t) =
    put_text (Jv.to_string c) ~classes:(Jv.to_string cls);
    Jv.undefined
  in
  let put_break_wrapped (_ : Jv.t) =
    put_break ();
    Jv.undefined
  in
  Jv.call
    (Lazy.force lezer_highlight)
    "highlightCode"
    [|
      Jv.of_string code;
      tr;
      Jv.of_list Fun.id hls;
      Jv.callback ~arity:2 put_text_wrapped;
      Jv.callback ~arity:1 put_break_wrapped;
      opt_int from;
      opt_int to_;
    |]
  |> ignore

type style_tags_result = { tags : Tag.t list; opaque : bool; inherit_ : bool }

let get_style_tags (node : syntax_node) : style_tags_result option =
  let r = Jv.call (Lazy.force lezer_highlight) "getStyleTags" [| node |] in
  if Jv.is_null r then None
  else
    Some
      {
        tags = Jv.get r "tags" |> Jv.to_list Fun.id;
        opaque = Jv.Bool.get r "opaque";
        inherit_ = Jv.Bool.get r "inherit";
      }

let pos_pair (j : Jv.t) = (Jv.Int.get j "from", Jv.Int.get j "to")

let jv_of_pos_pair (from, to_) =
  Jv.obj [| ("from", Jv.of_int from); ("to", Jv.of_int to_) |]

let fold_service :
    ( EditorState.t -> line_start:int -> line_end:int -> (int * int) option,
      Jv.t )
    Facet.t =
  let in_conv :
      (EditorState.t -> line_start:int -> line_end:int -> (int * int) option)
      Conv.t =
    {
      Conv.to_jv =
        (fun f ->
          let wrapped (st : Jv.t) (ls : Jv.t) (le : Jv.t) =
            match
              f (EditorState.of_jv st) ~line_start:(Jv.to_int ls)
                ~line_end:(Jv.to_int le)
            with
            | None -> Jv.null
            | Some p -> jv_of_pos_pair p
          in
          Jv.callback ~arity:3 wrapped);
      of_jv = (fun _ -> Conv.invalid "fold_service" Jv.null);
    }
  in
  Facet.of_jv in_conv Conv.jv (Jv.get (Lazy.force pkg) "foldService")

let fold_inside (node : syntax_node) : (int * int) option =
  let r = Jv.call (Lazy.force pkg) "foldInside" [| node |] in
  if Jv.is_null r then None else Some (pos_pair r)

let foldable (state : EditorState.t) ~line_start ~line_end : (int * int) option
    =
  let r =
    Jv.call (Lazy.force pkg) "foldable"
      [| EditorState.to_jv state; Jv.of_int line_start; Jv.of_int line_end |]
  in
  if Jv.is_null r then None else Some (pos_pair r)

let doc_range_conv : (int * int) Conv.t =
  { Conv.to_jv = jv_of_pos_pair; of_jv = pos_pair }

let fold_effect : (int * int) StateEffectType.t =
  StateEffectType.of_jv doc_range_conv (Jv.get (Lazy.force pkg) "foldEffect")

let unfold_effect : (int * int) StateEffectType.t =
  StateEffectType.of_jv doc_range_conv (Jv.get (Lazy.force pkg) "unfoldEffect")

let folded_ranges (state : EditorState.t) : Cm_view.Decoration.t RangeSet.t =
  (RangeSet.conv Cm_view.Decoration.conv).of_jv
    (Jv.call (Lazy.force pkg) "foldedRanges" [| EditorState.to_jv state |])

let command_of_jv (name : string) : Cm_view.command =
  let f = Jv.get (Lazy.force pkg) name in
  fun (view : Cm_view.editor_view) ->
    Jv.apply f [| Cm_view.EditorView.to_jv view |] |> Jv.to_bool

let fold_code = command_of_jv "foldCode"
let unfold_code = command_of_jv "unfoldCode"
let fold_all = command_of_jv "foldAll"
let unfold_all = command_of_jv "unfoldAll"
let toggle_fold = command_of_jv "toggleFold"

let fold_keymap : Cm_view.KeyBinding.t list =
  Jv.get (Lazy.force pkg) "foldKeymap" |> Jv.to_list Cm_view.KeyBinding.of_jv

let code_folding ?placeholder_text () : Extension.t =
  let o = Jv.obj [||] in
  Jv.set_if_some o "placeholderText" (Option.map Jv.of_string placeholder_text);
  Extension.of_jv (Jv.call (Lazy.force pkg) "codeFolding" [| o |])

let fold_gutter ?open_text ?closed_text ?dom_event_handlers ?folding_changed ()
    : Extension.t =
  let o = Jv.obj [||] in
  Jv.set_if_some o "openText" (Option.map Jv.of_string open_text);
  Jv.set_if_some o "closedText" (Option.map Jv.of_string closed_text);
  Option.iter
    (fun handlers ->
      let ho = Jv.obj [||] in
      List.iter
        (fun (name, f) ->
          let wrapped (view : Jv.t) (line : Jv.t) (ev : Jv.t) =
            Jv.of_bool
              (f
                 (Cm_view.EditorView.of_jv view)
                 (Cm_view.BlockInfo.of_jv line)
                 (Brr.Ev.of_jv ev))
          in
          Jv.set ho name (Jv.callback ~arity:3 wrapped))
        handlers;
      Jv.set o "domEventHandlers" ho)
    dom_event_handlers;
  Option.iter
    (fun f ->
      let wrapped (u : Jv.t) = Jv.of_bool (f (Cm_view.ViewUpdate.of_jv u)) in
      Jv.set o "foldingChanged" (Jv.callback ~arity:1 wrapped))
    folding_changed;
  Extension.of_jv (Jv.call (Lazy.force pkg) "foldGutter" [| o |])

type match_result = {
  start : int * int;
  end_ : (int * int) option;
  matched : bool;
}

let match_result_of_jv (r : Jv.t) : match_result =
  {
    start = pos_pair (Jv.get r "start");
    end_ = Option.map pos_pair (Jv.find r "end");
    matched = Jv.Bool.get r "matched";
  }

let bracket_matching ?after_cursor ?brackets ?max_scan_distance ?render_match ()
    : Extension.t =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "afterCursor" after_cursor;
  Jv.set_if_some o "brackets" (Option.map Jv.of_string brackets);
  Jv.Int.set_if_some o "maxScanDistance" max_scan_distance;
  Option.iter
    (fun f ->
      let wrapped (m : Jv.t) (st : Jv.t) =
        Jv.of_list
          (fun (r : Cm_view.Decoration.t Range.t) ->
            (Range.conv Cm_view.Decoration.conv).to_jv r)
          (f (match_result_of_jv m) (EditorState.of_jv st))
      in
      Jv.set o "renderMatch" (Jv.callback ~arity:2 wrapped))
    render_match;
  Extension.of_jv (Jv.call (Lazy.force pkg) "bracketMatching" [| o |])

let match_brackets (state : EditorState.t) ~pos ~dir ?brackets
    ?max_scan_distance () : match_result option =
  let dir_jv =
    match dir with `Backward -> Jv.of_int (-1) | `Forward -> Jv.of_int 1
  in
  let o = Jv.obj [||] in
  Jv.set_if_some o "brackets" (Option.map Jv.of_string brackets);
  Jv.Int.set_if_some o "maxScanDistance" max_scan_distance;
  let r =
    Jv.call (Lazy.force pkg) "matchBrackets"
      [| EditorState.to_jv state; Jv.of_int pos; dir_jv; o |]
  in
  if Jv.is_null r then None else Some (match_result_of_jv r)

let bidi_isolates ?always_isolate () : Extension.t =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "alwaysIsolate" always_isolate;
  Extension.of_jv (Jv.call (Lazy.force pkg) "bidiIsolates" [| o |])
