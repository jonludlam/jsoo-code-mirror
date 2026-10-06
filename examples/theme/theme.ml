open Code_mirror
open State
open View
open Brr

let init ?doc () =
  let config =
    EditorStateConfig.create ?doc
      ~extensions:(Extension.of_list [ Theme_one_dark.one_dark; basic_setup ])
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
