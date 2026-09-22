# Examples

One page per thing worth seeing. Each is `examples/<name>/` with a
`dune`, an `index.html` and one `.ml`, built with `(modes js)` against
the smallest set of libraries that example needs, so the pages also
demonstrate what depending on one package rather than all of them costs.

Every example page sets `window.exampleResults = {total, passed, failed,
details, done}` the way the tests do, asserting whatever it can about
itself, so the whole directory can be swept in a browser rather than
eyeballed one at a time.

## Ported from the existing set

| page | was | covers |
|---|---|---|
| highlight | examples/highlight | StateField of decorations, StateEffect with map, mark decorations, base_theme |
| panel | examples/panel | show_panel, StateField of bool, Facet.from, keymap |
| selection | examples/selection | TransactionSpec with changes and selection |
| theme | examples/theme | EditorView.theme, dark themes |
| compartment | added this branch | Compartment.reconfigure through a spec, line_numbers, line wrapping |
| widgets | added this branch | WidgetType, block widgets, effect mapping through changes |
| headless | added this branch | EditorState.update with no view, Transaction reading |

## New, one per package with nothing yet

| page | covers |
|---|---|
| language | StreamLanguage from a hand-written StreamParser, HighlightStyle, syntax_highlighting, syntax_tree walking |
| ocaml | the real thing: Cm_legacy_modes.ocaml + one_dark + basic_setup, i.e. what a page embedding an OCaml editor actually writes |
| commands | default_keymap, history, undo/redo, indent_more, toggle_comment driven by buttons |
| autocomplete | complete_from_list and a source of our own, close_brackets, a snippet |
| lint | a linter over the document, the lint gutter, the panel |
| search | the search panel, find_next, replace_all, highlight_selection_matches |
| gutter | a custom GutterMarker gutter beside line_numbers |
| tooltip | hover_tooltip showing the word under the cursor |
| view_plugin | a ViewPlugin maintaining decorations as the viewport moves |

## Index

`examples/index.html` lists them all with a line each, so the directory
is browsable. `examples/dune` keeps the existing `serve.py` alias.
