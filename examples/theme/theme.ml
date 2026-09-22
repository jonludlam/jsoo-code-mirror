(* Themes: an editor's colours come from an extension, so a page can stack
   them. Here the One Dark theme from its own package, with a small theme
   of our own on top, built with EditorView.theme. *)

open Code_mirror
open Brr

let mine =
  View.EditorView.theme ~dark:true
    View.StyleSpec.
      [
        ("&", Rules [ ("maxWidth", Value "40em") ]);
        (".cm-content", Rules [ ("fontFamily", Value "monospace") ]);
      ]

let () =
  let config =
    State.EditorStateConfig.create ~doc:"One Dark, with a theme of our own."
      ~extensions:
        (State.Extension.of_list
           [ Theme_one_dark.one_dark; mine; basic_setup ])
      ()
  in
  let state = State.EditorState.create ~config () in
  let view =
    View.EditorView.create
      ~config:
        (View.EditorViewConfig.create ~state
           ~parent:(Document.body G.document) ())
      ()
  in
  ignore view
