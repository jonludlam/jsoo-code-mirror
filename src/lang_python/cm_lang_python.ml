let pkg = lazy (Jv.get Jv.global "__CM__lang_python")
let lezer = lazy (Jv.get Jv.global "__CM__lezer_python")
let get n = Jv.get (Lazy.force pkg) n
let source = Cm_autocomplete.completion_source_conv

let python () =
  Cm_language.LanguageSupport.of_jv (Jv.call (Lazy.force pkg) "python" [||])

let python_language = Cm_language.LRLanguage.of_jv (get "pythonLanguage")
let local_completion_source = source.of_jv (get "localCompletionSource")
let global_completion = source.of_jv (get "globalCompletion")
let parser = Cm_language.LRParser.of_jv (Jv.get (Lazy.force lezer) "parser")
