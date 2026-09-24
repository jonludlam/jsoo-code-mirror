(** {{:https://github.com/codemirror/lang-html} \@codemirror/lang-html}: HTML
    support, with CSS and JavaScript in [<style>] and [<script>], and the
    [\@lezer/html] parser it is built on. *)

open Cm_state

(** {{:https://codemirror.net/docs/ref/#lang-html.TagSpec} lang-html.TagSpec}:
    what completion offers inside a tag. *)
module TagSpec : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?attrs:(string * string list option) list ->
    ?global_attrs:bool ->
    ?children:string list ->
    unit ->
    t
  (** An attribute with [None] takes free-form values; [Some values] suggests
      them. *)
end

type nested_lang = {
  tag : string;
  attrs : ((string * string) list -> bool) option;
      (** given the tag's attributes, whether this language applies *)
  parser : Cm_language.Parser.t;
}
(** A language for the content of some tags, for [html]'s [nested_languages]. *)

type nested_attr = {
  name : string;
  tag_name : string option;
  parser : Cm_language.Parser.t;
}
(** A language for some attribute values, for [html]'s [nested_attributes]. *)

val html :
  ?match_closing_tags:bool ->
  ?self_closing_tags:bool ->
  ?auto_close_tags:bool ->
  ?extra_tags:(string * TagSpec.t) list ->
  ?extra_global_attributes:(string * string list option) list ->
  ?nested_languages:nested_lang list ->
  ?nested_attributes:nested_attr list ->
  unit ->
  Cm_language.LanguageSupport.t
(** {{:https://codemirror.net/docs/ref/#lang-html.html} lang-html.html} *)

val html_language : Cm_language.LRLanguage.t
(** {{:https://codemirror.net/docs/ref/#lang-html.htmlLanguage}
     lang-html.htmlLanguage} *)

val auto_close_tags : Extension.t
(** {{:https://codemirror.net/docs/ref/#lang-html.autoCloseTags}
     lang-html.autoCloseTags} *)

val html_completion_source : Cm_autocomplete.completion_source
(** {{:https://codemirror.net/docs/ref/#lang-html.htmlCompletionSource}
     lang-html.htmlCompletionSource} *)

val html_completion_source_with :
  ?extra_tags:(string * TagSpec.t) list ->
  ?extra_global_attributes:(string * string list option) list ->
  unit ->
  Cm_autocomplete.completion_source
(** {{:https://codemirror.net/docs/ref/#lang-html.htmlCompletionSourceWith}
     lang-html.htmlCompletionSourceWith} *)

val parser : Cm_language.LRParser.t
(** [\@lezer/html]'s parser. *)
