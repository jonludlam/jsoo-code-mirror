(* https://codemirror.net/examples/gutter/ *)

open Brr
open Cm_state
open Cm_view

(*!emptyLineGutter*)

let empty_marker = GutterMarker.make ~to_dom:(fun _ -> El.txt' "ø") ()

let empty_line_gutter =
  gutter
    ~line_marker:(fun _view line _others ->
      if BlockInfo.from line = BlockInfo.to_ line then Some empty_marker
      else None)
    ~initial_spacer:(fun _ -> empty_marker)
    ()

(*!breakpointState*)

type breakpoint = { pos : int; on : bool }

let breakpoint_effect =
  StateEffectType.define
    ~map:(fun v mapping ->
      Option.map (fun pos -> { v with pos }) (ChangeDesc.map_pos mapping v.pos))
    {
      Conv.to_jv =
        (fun v ->
          Jv.obj [| ("pos", Jv.of_int v.pos); ("on", Jv.of_bool v.on) |]);
      of_jv = (fun o -> { pos = Jv.Int.get o "pos"; on = Jv.Bool.get o "on" });
    }

(* Upstream defines this in its breakpointGutter section; JavaScript can
   use it before then, OCaml needs it first. *)
let breakpoint_marker = GutterMarker.make ~to_dom:(fun _ -> El.txt' "💔") ()

let breakpoint_state : GutterMarker.t RangeSet.t StateField.t =
  StateField.define
    (RangeSet.conv_of GutterMarker.conv)
    ~create:(fun _ -> RangeSet.empty GutterMarker.conv)
    ~update:(fun set transaction ->
      let set =
        RangeSet.map set (ChangeSet.desc (Transaction.changes transaction))
      in
      List.fold_left
        (fun set e ->
          match StateEffect.value e breakpoint_effect with
          | Some { pos; on = true } ->
              RangeSet.update
                ~add:[ GutterMarker.range breakpoint_marker ~from:pos ]
                set
          | Some { pos; on = false } ->
              RangeSet.update ~filter:(fun ~from ~to_:_ _ -> from <> pos) set
          | None -> set)
        set
        (Transaction.effects transaction))

let toggle_breakpoint view pos =
  let breakpoints =
    EditorState.field (EditorView.state view) breakpoint_state
  in
  let has_breakpoint = ref false in
  RangeSet.between ~from:pos ~to_:pos breakpoints (fun ~from:_ ~to_:_ _ ->
      has_breakpoint := true;
      true);
  EditorView.dispatch view
    (TransactionSpec.create
       ~effects:
         [
           StateEffectType.of_ breakpoint_effect
             { pos; on = not !has_breakpoint };
         ]
       ())

(*!breakpointGutter*)

let breakpoint_gutter =
  Extension.of_list
    [
      StateField.extension breakpoint_state;
      gutter ~class_:"cm-breakpoint-gutter"
        ~markers:(fun v ->
          EditorState.field (EditorView.state v) breakpoint_state)
        ~initial_spacer:(fun _ -> breakpoint_marker)
        ~dom_event_handlers:
          [
            ( "mousedown",
              fun view line _event ->
                toggle_breakpoint view (BlockInfo.from line);
                true );
          ]
        ();
      EditorView.base_theme
        StyleSpec.
          [
            ( ".cm-breakpoint-gutter .cm-gutterElement",
              Rules
                [
                  ("color", Value "red");
                  ("paddingLeft", Value "5px");
                  ("cursor", Value "default");
                ] );
          ];
    ]

(*!show*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"Some\ntext\nwith\n\nblank\n\nlines\n.\n"
         ~extensions:
           (Extension.of_list
              [ breakpoint_gutter; Code_mirror.basic_setup; empty_line_gutter ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()
