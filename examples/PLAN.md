# Examples

One page per thing worth seeing. Each is `examples/<name>/` with a
`dune`, an `index.html` and one `.ml`, built with `(modes js)` against
the smallest set of libraries that example needs, so the pages also
demonstrate what depending on one package rather than all of them costs.

Every example page sets `window.exampleResults = {total, passed, failed,
details, done}` the way the tests do, asserting whatever it can about
itself, so the whole directory can be swept in a browser rather than
eyeballed one at a time. The checks share `examples/check`, and leave
the page as it opened: a check passes the views it will change to
`keep`, and `report` puts their states back.

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

## Ported from codemirror.net/examples

`upstream/<name>/` holds every upstream example, under upstream's name,
as close to the original as OCaml allows: one `.ml` per upstream file,
keeping its names and its `//!section` markers as `(*!section*)`, so a
reader can hold the page and the port side by side. The page's markup
and CSS come from upstream's `index.md`. The self-check is a separate
`selfcheck.ml`, over the shared `examples/check` library, so the ported
files carry nothing that is not in the original.

Where OCaml has to differ, the port says so where it happens: a value
JavaScript uses before defining it is defined first; `changeByRange`'s
result is made into a spec; a JavaScript class with fields is a
`WidgetType.define`; the two grammar examples load the parser their
dune rule generates; collab's worker is a second program, in `worker/`.
`ie11` is not ported, being about transpiling for Internet Explorer.

## Index

`examples/index.html` lists them all with a line each, so the directory
is browsable. `examples/dune` keeps the existing `serve.py` alias.
