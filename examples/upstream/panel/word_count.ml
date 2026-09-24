(* https://codemirror.net/examples/panel/, its second editor *)

open Brr
open Cm_state
open Cm_view

(*!countWords*)

(* JavaScript's [/\w/]. *)
let is_word c =
  (c >= 'a' && c <= 'z')
  || (c >= 'A' && c <= 'Z')
  || (c >= '0' && c <= '9')
  || c = '_'

let count_words doc =
  let count = ref 0 in
  Text.iter doc (fun value ~line_break:_ ->
      let in_word = ref false in
      String.iter
        (fun c ->
          let word = is_word c in
          if word && not !in_word then incr count;
          in_word := word)
        value);
  Printf.sprintf "Word count: %d" !count

(*!wordCountPanel*)

let word_count_panel view =
  let dom =
    El.div [ El.txt' (count_words (EditorState.doc (EditorView.state view))) ]
  in
  Panel.create
    ~update:(fun update ->
      if ViewUpdate.doc_changed update then
        El.set_children dom
          [ El.txt' (count_words (EditorState.doc (ViewUpdate.state update))) ])
    dom

(*!wordCounter*)

let word_counter () = Facet.of_ show_panel (Some word_count_panel)

(*!create*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:"Type here and the editor will count your\nwords."
         ~extensions:
           (Extension.of_list [ Code_mirror.basic_setup; word_counter () ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "count-editor")))
         ())
    ()
