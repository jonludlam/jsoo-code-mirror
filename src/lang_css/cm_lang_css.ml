let pkg = lazy (Jv.get Jv.global "__CM__lang_css")
let lezer = lazy (Jv.get Jv.global "__CM__lezer_css")
let get n = Jv.get (Lazy.force pkg) n
let source = Cm_autocomplete.completion_source_conv

let css () =
  Cm_language.LanguageSupport.of_jv (Jv.call (Lazy.force pkg) "css" [||])

let css_language = Cm_language.LRLanguage.of_jv (get "cssLanguage")
let css_completion_source = source.of_jv (get "cssCompletionSource")

let define_css_completion_source is_variable =
  let f =
    Jv.callback ~arity:1 (fun n ->
        Jv.of_bool
          (is_variable (Cm_language.SyntaxNode.of_jv (Jv.get n "node"))))
  in
  source.of_jv (Jv.call (Lazy.force pkg) "defineCSSCompletionSource" [| f |])

let parser = Cm_language.LRParser.of_jv (Jv.get (Lazy.force lezer) "parser")
