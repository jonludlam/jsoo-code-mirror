(* https://codemirror.net/examples/tooltip/, its second editor *)

open Brr
open Cm_state
open Cm_view

(*!hoverTooltip*)

(* JavaScript's [/\w/]. *)
let is_word c =
  (c >= 'a' && c <= 'z')
  || (c >= 'A' && c <= 'Z')
  || (c >= '0' && c <= '9')
  || c = '_'

let word_hover =
  hover_tooltip (fun view ~pos ~side ->
      let line = Text.line_at (EditorState.doc (EditorView.state view)) pos in
      let from = Line.from line
      and to_ = Line.to_ line
      and text = Line.text line in
      let start = ref pos and end_ = ref pos in
      while !start > from && is_word text.[!start - from - 1] do
        decr start
      done;
      while !end_ < to_ && is_word text.[!end_ - from] do
        incr end_
      done;
      if (!start = pos && side < 0) || (!end_ = pos && side > 0) then
        Fut.return None
      else
        let start = !start and end_ = !end_ in
        Fut.return
          (Some
             (Tooltip.create ~pos:start ~end_ ~above:true
                ~create:(fun _ ->
                  TooltipView.create
                    (El.div
                       [
                         El.txt' (String.sub text (start - from) (end_ - start));
                       ]))
                ())))

(*!create*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"Hover over words to get tooltips\n"
         ~extensions:(Extension.of_list [ Code_mirror.basic_setup; word_hover ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "hover-editor")))
         ())
    ()
