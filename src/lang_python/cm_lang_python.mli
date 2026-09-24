(** {{:https://github.com/codemirror/lang-python} \@codemirror/lang-python}:
    Python support, and the [\@lezer/python] parser it is built on. *)

val python : unit -> Cm_language.LanguageSupport.t
(** {{:https://codemirror.net/docs/ref/#lang-python.python} lang-python.python}:
    the language with local and global completion. *)

val python_language : Cm_language.LRLanguage.t
(** {{:https://codemirror.net/docs/ref/#lang-python.pythonLanguage}
     lang-python.pythonLanguage} *)

val local_completion_source : Cm_autocomplete.completion_source
(** {{:https://codemirror.net/docs/ref/#lang-python.localCompletionSource}
     lang-python.localCompletionSource} *)

val global_completion : Cm_autocomplete.completion_source
(** {{:https://codemirror.net/docs/ref/#lang-python.globalCompletion}
     lang-python.globalCompletion}: builtins and keywords. *)

val parser : Cm_language.LRParser.t
(** [\@lezer/python]'s parser. *)
