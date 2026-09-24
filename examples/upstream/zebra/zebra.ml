(* https://codemirror.net/examples/zebra/ *)

open Brr
open Cm_state
open Cm_view

(*!baseTheme*)

let base_theme =
  EditorView.base_theme
    StyleSpec.
      [
        ( "&light .cm-zebraStripe",
          Rules [ ("backgroundColor", Value "#a4f1f188") ] );
        ( "&dark .cm-zebraStripe",
          Rules [ ("backgroundColor", Value "#34474788") ] );
      ]

(*!facet*)

let step_size : (int, int) Facet.t =
  Facet.define
    ~combine:(function [] -> 2 | v :: vs -> List.fold_left min v vs)
    Conv.int Conv.int

(*!stripeDeco*)

let stripe = Decoration.line ~attributes:[ ("class", "cm-zebraStripe") ] ()

let stripe_deco view =
  let step = EditorState.facet (EditorView.state view) step_size in
  let builder = RangeSetBuilder.make Decoration.conv () in
  List.iter
    (fun (from, to_) ->
      let pos = ref from in
      while !pos <= to_ do
        let line =
          Text.line_at (EditorState.doc (EditorView.state view)) !pos
        in
        if Line.number line mod step = 0 then
          RangeSetBuilder.add builder ~from:(Line.from line)
            ~to_:(Line.from line) stripe;
        pos := Line.to_ line + 1
      done)
    (EditorView.visible_ranges view);
  RangeSetBuilder.finish builder

(*!showStripes*)

type show_stripes = { mutable decorations : Decoration.t RangeSet.t }

let show_stripes =
  ViewPlugin.define
    ~update:(fun this update ->
      if ViewUpdate.doc_changed update || ViewUpdate.viewport_changed update
      then this.decorations <- stripe_deco (ViewUpdate.view update))
    ~decorations:(fun v -> v.decorations)
    (fun view -> { decorations = stripe_deco view })

(*!constructor*)

let zebra_stripes ?step () =
  Extension.of_list
    [
      base_theme;
      (match step with
      | None -> Extension.empty
      | Some step -> Facet.of_ step_size step);
      ViewPlugin.extension show_stripes;
    ]

(*!example*)

let text = List.init 100 (fun i -> "line " ^ string_of_int (i + 1))

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~extensions:
           (Extension.of_list
              [ zebra_stripes (); Facet.of_ keymap Cm_commands.default_keymap ])
         ~doc:(String.concat "\n" text)
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()

let () = Jv.set Jv.global "view" (EditorView.to_jv view)
