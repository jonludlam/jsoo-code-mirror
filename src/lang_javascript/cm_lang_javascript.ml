let pkg = lazy (Jv.get Jv.global "__CM__lang_javascript")
let lezer = lazy (Jv.get Jv.global "__CM__lezer_javascript")
let get n = Jv.get (Lazy.force pkg) n
let source = Cm_autocomplete.completion_source_conv

let javascript ?jsx ?typescript () =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "jsx" jsx;
  Jv.Bool.set_if_some o "typescript" typescript;
  Cm_language.LanguageSupport.of_jv
    (Jv.call (Lazy.force pkg) "javascript" [| o |])

let lr n = Cm_language.LRLanguage.of_jv (get n)
let javascript_language = lr "javascriptLanguage"
let typescript_language = lr "typescriptLanguage"
let jsx_language = lr "jsxLanguage"
let tsx_language = lr "tsxLanguage"
let auto_close_tags = Cm_state.Extension.of_jv (get "autoCloseTags")
let completions n = Jv.to_list Cm_autocomplete.Completion.of_jv (get n)
let snippets = completions "snippets"
let typescript_snippets = completions "typescriptSnippets"
let local_completion_source = source.of_jv (get "localCompletionSource")

let completion_path ctx =
  let r =
    Jv.call (Lazy.force pkg) "completionPath"
      [| Cm_autocomplete.CompletionContext.to_jv ctx |]
  in
  if Jv.is_null r then None
  else
    Some
      (Jv.to_list Jv.to_string (Jv.get r "path"), Jv.to_string (Jv.get r "name"))

let scope_completion_source scope =
  source.of_jv (Jv.call (Lazy.force pkg) "scopeCompletionSource" [| scope |])

let parser = Cm_language.LRParser.of_jv (Jv.get (Lazy.force lezer) "parser")
