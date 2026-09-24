let pkg = lazy (Jv.get Jv.global "__CM__lang_html")
let lezer = lazy (Jv.get Jv.global "__CM__lezer_html")
let get n = Jv.get (Lazy.force pkg) n
let source = Cm_autocomplete.completion_source_conv

let attr_values (attrs : (string * string list option) list) =
  Jv.obj
    (Array.of_list
       (List.map
          (fun (name, values) ->
            ( name,
              match values with
              | None -> Jv.null
              | Some l -> Jv.of_list Jv.of_string l ))
          attrs))

module TagSpec = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?attrs ?global_attrs ?children () : t =
    let o = Jv.obj [||] in
    Jv.set_if_some o "attrs" (Option.map attr_values attrs);
    Jv.Bool.set_if_some o "globalAttrs" global_attrs;
    Jv.set_if_some o "children" (Option.map (Jv.of_list Jv.of_string) children);
    o
end

type nested_lang = {
  tag : string;
  attrs : ((string * string) list -> bool) option;
  parser : Cm_language.Parser.t;
}

type nested_attr = {
  name : string;
  tag_name : string option;
  parser : Cm_language.Parser.t;
}

let tag_specs l = Jv.obj (Array.of_list l)

let set_tags o ?extra_tags ?extra_global_attributes () =
  Jv.set_if_some o "extraTags" (Option.map tag_specs extra_tags);
  Jv.set_if_some o "extraGlobalAttributes"
    (Option.map attr_values extra_global_attributes)

let nested_lang_to_jv (n : nested_lang) =
  let o =
    Jv.obj
      [|
        ("tag", Jv.of_string n.tag);
        ("parser", Cm_language.Parser.to_jv n.parser);
      |]
  in
  Option.iter
    (fun f ->
      Jv.set o "attrs"
        (Jv.callback ~arity:1 (fun a ->
             let names =
               Jv.to_list Jv.to_string
                 (Jv.call (Jv.get Jv.global "Object") "keys" [| a |])
             in
             Jv.of_bool
               (f (List.map (fun k -> (k, Jv.to_string (Jv.get a k))) names)))))
    n.attrs;
  o

let nested_attr_to_jv (n : nested_attr) =
  let o =
    Jv.obj
      [|
        ("name", Jv.of_string n.name);
        ("parser", Cm_language.Parser.to_jv n.parser);
      |]
  in
  Jv.set_if_some o "tagName" (Option.map Jv.of_string n.tag_name);
  o

let html ?match_closing_tags ?self_closing_tags ?auto_close_tags ?extra_tags
    ?extra_global_attributes ?nested_languages ?nested_attributes () =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "matchClosingTags" match_closing_tags;
  Jv.Bool.set_if_some o "selfClosingTags" self_closing_tags;
  Jv.Bool.set_if_some o "autoCloseTags" auto_close_tags;
  set_tags o ?extra_tags ?extra_global_attributes ();
  Jv.set_if_some o "nestedLanguages"
    (Option.map (Jv.of_list nested_lang_to_jv) nested_languages);
  Jv.set_if_some o "nestedAttributes"
    (Option.map (Jv.of_list nested_attr_to_jv) nested_attributes);
  Cm_language.LanguageSupport.of_jv (Jv.call (Lazy.force pkg) "html" [| o |])

let html_language = Cm_language.LRLanguage.of_jv (get "htmlLanguage")
let auto_close_tags = Cm_state.Extension.of_jv (get "autoCloseTags")
let html_completion_source = source.of_jv (get "htmlCompletionSource")

let html_completion_source_with ?extra_tags ?extra_global_attributes () =
  let o = Jv.obj [||] in
  set_tags o ?extra_tags ?extra_global_attributes ();
  source.of_jv (Jv.call (Lazy.force pkg) "htmlCompletionSourceWith" [| o |])

let parser = Cm_language.LRParser.of_jv (Jv.get (Lazy.force lezer) "parser")
