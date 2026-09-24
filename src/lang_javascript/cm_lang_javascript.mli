(** {{:https://github.com/codemirror/lang-javascript}
     \@codemirror/lang-javascript}: JavaScript, TypeScript and JSX support, and
    the [\@lezer/javascript] parser it is built on. *)

open Cm_state

val javascript :
  ?jsx:bool -> ?typescript:bool -> unit -> Cm_language.LanguageSupport.t
(** {{:https://codemirror.net/docs/ref/#lang-javascript.javascript}
     lang-javascript.javascript}: the dialect the flags pick, with its
    completion and snippets. *)

val javascript_language : Cm_language.LRLanguage.t
(** {{:https://codemirror.net/docs/ref/#lang-javascript.javascriptLanguage}
     lang-javascript.javascriptLanguage} *)

val typescript_language : Cm_language.LRLanguage.t
val jsx_language : Cm_language.LRLanguage.t
val tsx_language : Cm_language.LRLanguage.t

val auto_close_tags : Extension.t
(** {{:https://codemirror.net/docs/ref/#lang-javascript.autoCloseTags}
     lang-javascript.autoCloseTags}: closing JSX tags as they are typed. *)

val snippets : Cm_autocomplete.Completion.t list
(** {{:https://codemirror.net/docs/ref/#lang-javascript.snippets}
     lang-javascript.snippets} *)

val typescript_snippets : Cm_autocomplete.Completion.t list

val local_completion_source : Cm_autocomplete.completion_source
(** {{:https://codemirror.net/docs/ref/#lang-javascript.localCompletionSource}
     lang-javascript.localCompletionSource}: the names in scope at the cursor.
*)

val completion_path :
  Cm_autocomplete.CompletionContext.t -> (string list * string) option
(** {{:https://codemirror.net/docs/ref/#lang-javascript.completionPath}
     lang-javascript.completionPath}: the property path before the cursor and
    the name being typed, as [(path, name)]. *)

val scope_completion_source : Jv.t -> Cm_autocomplete.completion_source
(** {{:https://codemirror.net/docs/ref/#lang-javascript.scopeCompletionSource}
     lang-javascript.scopeCompletionSource}: completion of the properties of a
    JavaScript object, such as [Jv.global]. *)

val parser : Cm_language.LRParser.t
(** [\@lezer/javascript]'s parser. *)

(** Not bound:

    - [esLint]: it needs an ESLint instance, which the page would have to load
      itself, and its result is a lint source, which would make every page using
      JavaScript link [\@codemirror/lint]. *)
