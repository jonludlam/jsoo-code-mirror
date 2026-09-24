# Cm_lang_javascript: @codemirror/lang-javascript

Depends on Cm_state, Cm_language and Cm_autocomplete, Cm_view.
The bundle carries the package and the Lezer parser it is built on; the
parser is `parser`, for nesting it in another grammar with
`Cm_language.parse_mixed`.

Everything but `esLint`, which needs an ESLint instance the page would load itself, and whose lint-source result would make every JavaScript page link `@codemirror/lint`.
