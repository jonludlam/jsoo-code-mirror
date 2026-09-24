(* https://codemirror.net/examples/tooltip/ *)

open Brr
open Cm_state
open Cm_view

(*!getCursorTooltips*)

let get_cursor_tooltips state =
  EditorSelection.ranges (EditorState.selection state)
  |> List.filter SelectionRange.empty
  |> List.map (fun range ->
         let line =
           Text.line_at (EditorState.doc state) (SelectionRange.head range)
         in
         let text =
           string_of_int (Line.number line)
           ^ ":"
           ^ string_of_int (SelectionRange.head range - Line.from line)
         in
         Tooltip.create
           ~pos:(SelectionRange.head range)
           ~above:true ~strict_side:true ~arrow:true
           ~create:(fun _ ->
             let dom =
               El.div
                 ~at:At.[ class' (Jstr.v "cm-tooltip-cursor") ]
                 [ El.txt' text ]
             in
             TooltipView.create dom)
           ())

(*!cursorTooltipField*)

let cursor_tooltip_field : Tooltip.t list StateField.t =
  StateField.define
    (Conv.list (Conv.of_module (module Tooltip)))
    ~create:get_cursor_tooltips
    ~update:(fun tooltips tr ->
      if (not (Transaction.doc_changed tr)) && Transaction.selection tr = None
      then tooltips
      else get_cursor_tooltips (Transaction.state tr))
    ~provide:(fun f ->
      Facet.compute_n show_tooltip ~deps:[ Field_dep f ] (fun state ->
          List.map Option.some (EditorState.field state f)))

(*!baseTheme*)

let cursor_tooltip_base_theme =
  EditorView.base_theme
    StyleSpec.
      [
        ( ".cm-tooltip.cm-tooltip-cursor",
          Rules
            [
              ("backgroundColor", Value "#66b");
              ("color", Value "white");
              ("border", Value "none");
              ("padding", Value "2px 7px");
              ("borderRadius", Value "4px");
              ( "& .cm-tooltip-arrow:before",
                Rules [ ("borderTopColor", Value "#66b") ] );
              ( "& .cm-tooltip-arrow:after",
                Rules [ ("borderTopColor", Value "transparent") ] );
            ] );
      ]

(*!cursorTooltip*)

let cursor_tooltip () =
  Extension.of_list
    [ StateField.extension cursor_tooltip_field; cursor_tooltip_base_theme ]

(*!create*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:"Move through this text to\nsee your tooltip\n"
         ~extensions:
           (Extension.of_list [ Code_mirror.basic_setup; cursor_tooltip () ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()
