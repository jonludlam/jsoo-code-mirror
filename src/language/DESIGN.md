# Cm_language

Bind `@codemirror/language` (node_modules/@codemirror/language/dist/index.d.ts)
plus what the bundle also exposes: `__CM__lezer_common`, `__CM__lezer_highlight`,
`__CM__lezer_lr`. Depends on Cm_state and Cm_view (`open Cm_state`).

Fixed points:
- `module Language`, `module LRLanguage`, `module LanguageSupport`,
  `module LanguageDescription`, `module StreamLanguage` (with
  `StreamParser` as the record of callbacks it takes; bind `define :
  StreamParser.t -> StreamLanguage.t` where `StreamParser.t` is built with
  `StreamParser.create ~token ?start_state ?copy_state ?indent ?blank_line
  ?language_data ?token_table ()` over a `StringStream.t` module with
  `next`, `peek`, `eat`, `eat_while`, `match_`, `sol`, `eol`, `skip_to_end`,
  `current`, `indentation`, `pos`, `start`, `string`).
- `module HighlightStyle` with `define : ?scope -> ?all -> ?theme_type ->
  TagStyle.t list -> t`, `default_highlight_style`, `syntax_highlighting :
  ?fallback:bool -> HighlightStyle.t -> Extension.t`, `module Tag`/`Tags`
  exposing lezer's `tags` (`Tags.keyword`, `Tags.comment`, ...) as values.
- Free functions as package values: `language`, `syntax_tree`,
  `ensure_syntax_tree`, `syntax_parser_running`, `indent_unit`,
  `indent_on_input`, `indent_string`, `get_indent_unit`,
  `bracket_matching`, `match_brackets`, `fold_gutter`, `fold_keymap`,
  `code_folding`, `fold_service`, `folded_ranges`, `fold_effect`,
  `unfold_effect`, `fold_all`, `unfold_all`, `toggle_fold`,
  `highlight_active_line`? (no, that is view), `language_data_prop`,
  `sublanguage_prop`, `define_language_facet`, `indent_service`,
  `IndentContext` module, `TreeIndentContext`, `delimited_indent`,
  `continued_indent`, `flat_indent`, `get_indentation`, `indent_range`,
  `bidi_isolates`.
- lezer: `module Tree`, `module SyntaxNode` (name, from, to_, parent,
  first_child, last_child, child_after, child_before, next_sibling,
  prev_sibling, resolve, resolve_inner, enter, get_child, get_children,
  type_), `module NodeType`, `module NodeProp` minimal, `module Parser`
  minimal. Keep these to what `Cm_language` itself returns or takes.
- Record what you leave out under "Not bound".
