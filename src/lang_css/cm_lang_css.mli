(** {{:https://github.com/codemirror/lang-css} \@codemirror/lang-css}: CSS
    language support, and the [\@lezer/css] parser it is built on. *)

val css : unit -> Cm_language.LanguageSupport.t
(** {{:https://codemirror.net/docs/ref/#lang-css.css} lang-css.css}: the
    language with its completion source. *)

val css_language : Cm_language.LRLanguage.t
(** {{:https://codemirror.net/docs/ref/#lang-css.cssLanguage}
     lang-css.cssLanguage} *)

val css_completion_source : Cm_autocomplete.completion_source
(** {{:https://codemirror.net/docs/ref/#lang-css.cssCompletionSource}
     lang-css.cssCompletionSource}: property, value, pseudo-class and tag
    completion. *)

val define_css_completion_source :
  (Cm_language.syntax_node -> bool) -> Cm_autocomplete.completion_source
(** {{:https://codemirror.net/docs/ref/#lang-css.defineCSSCompletionSource}
     lang-css.defineCSSCompletionSource}: the same completion, for a dialect
    whose variables are the nodes the predicate accepts. *)

val parser : Cm_language.LRParser.t
(** [\@lezer/css]'s parser. *)
