open Cm_state
open Cm_view
open Brr

let init ?doc () =
  let config =
    EditorStateConfig.create ?doc
      ~extensions:
        (Extension.of_list
           [ Cm_theme_one_dark.one_dark; Code_mirror.basic_setup ])
      ()
  in
  let state = EditorState.create ~config () in
  let config =
    EditorViewConfig.create ~state ~parent:(Document.body G.document) ()
  in
  let view = EditorView.create ~config () in
  (state, view)

let _ =
  let _ = init ~doc:"Example of the 'one-dark' theme" () in
  ()
