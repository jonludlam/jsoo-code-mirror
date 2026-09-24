(* https://codemirror.net/examples/styling/

   Upstream's page is snippets; each is used by an editor here. Its CSS
   snippet is in this page's index.html. *)

open Brr
open Cm_view
open Cm_language

let my_theme =
  EditorView.theme ~dark:true
    StyleSpec.
      [
        ( "&",
          Rules [ ("color", Value "white"); ("backgroundColor", Value "#034") ]
        );
        (".cm-content", Rules [ ("caretColor", Value "#0e9") ]);
        ("&.cm-focused .cm-cursor", Rules [ ("borderLeftColor", Value "#0e9") ]);
        ( "&.cm-focused .cm-selectionBackground, ::selection",
          Rules [ ("backgroundColor", Value "#074") ] );
        ( ".cm-gutters",
          Rules
            [
              ("backgroundColor", Value "#045");
              ("color", Value "#ddd");
              ("border", Value "none");
            ] );
      ]

let base_theme =
  EditorView.base_theme
    StyleSpec.
      [
        ( ".cm-o-replacement",
          Rules
            [
              ("display", Value "inline-block");
              ("width", Value ".5em");
              ("height", Value ".5em");
              ("borderRadius", Value ".25em");
            ] );
        ("&light .cm-o-replacement", Rules [ ("backgroundColor", Value "#04c") ]);
        ("&dark .cm-o-replacement", Rules [ ("backgroundColor", Value "#5bf") ]);
      ]

let my_highlight_style =
  HighlightStyle.define
    [
      TagStyle.make
        ~style:StyleSpec.[ ("color", Value "#fc6") ]
        [ Tags.keyword ];
      TagStyle.make
        ~style:
          StyleSpec.[ ("color", Value "#f5d"); ("fontStyle", Value "italic") ]
        [ Tags.comment ];
    ]

(* In your extensions... *)
let highlighting = syntax_highlighting my_highlight_style

let fixed_height_editor =
  EditorView.theme
    StyleSpec.
      [
        ("&", Rules [ ("height", Value "300px") ]);
        (".cm-scroller", Rules [ ("overflow", Value "auto") ]);
      ]

let min_height_editor =
  EditorView.theme
    StyleSpec.
      [ (".cm-content, .cm-gutter", Rules [ ("minHeight", Value "200px") ]) ]

let editor extensions doc =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc
         ~extensions:
           (Cm_state.Extension.of_list (Code_mirror.basic_setup :: extensions))
         ~parent:(Document.body G.document) ())
    ()

let js = LanguageSupport.extension (Cm_lang_javascript.javascript ())

let themed =
  editor
    [ my_theme; base_theme; highlighting; js ]
    "// A dark theme, and our own highlight style\nif (true) return \"yes\"\n"

let fixed = editor [ fixed_height_editor ] "A fixed height of 300px"
let min_height = editor [ min_height_editor ] "At least 200px tall"
