# Cm_lang_html: @codemirror/lang-html

Depends on Cm_state, Cm_language and Cm_autocomplete, Cm_view, Cm_lang_css and Cm_lang_javascript.
The bundle carries the package and the Lezer parser it is built on; the
parser is `parser`, for nesting it in another grammar with
`Cm_language.parse_mixed`.

Everything the package exports. `html`'s nested records (`TagSpec`, nested languages and attributes) are OCaml records and a `TagSpec` constructor; attribute maps are association lists.
