(* https://codemirror.net/examples/inverted-effect/ *)

open Brr
open Cm_state
open Cm_view

type range = { from : int; to_ : int }

(* How a [{from, to}] effect value crosses to JavaScript and back. *)
let range_conv : range Conv.t =
  {
    to_jv =
      (fun r ->
        Jv.obj [| ("from", Jv.of_int r.from); ("to", Jv.of_int r.to_) |]);
    of_jv = (fun o -> { from = Jv.Int.get o "from"; to_ = Jv.Int.get o "to" });
  }

(*!effect*)

let map_range range change =
  match
    (ChangeDesc.map_pos change range.from, ChangeDesc.map_pos change range.to_)
  with
  | Some from, Some to_ when from < to_ -> Some { from; to_ }
  | _ -> None

let add_highlight = StateEffectType.define ~map:map_range range_conv
let remove_highlight = StateEffectType.define ~map:map_range range_conv

(*!field*)

let highlight =
  Decoration.mark
    ~attributes:[ ("style", "background-color: rgba(255, 50, 0, 0.3)") ]
    ()

(*!cutRange*)

let cut_range ranges r =
  let leftover = ref [] in
  RangeSet.between ~from:r.from ~to_:r.to_ ranges (fun ~from ~to_ deco ->
      if from < r.from then
        leftover := Decoration.range deco ~from ~to_:r.from :: !leftover;
      if to_ > r.to_ then
        leftover := Decoration.range deco ~from:r.to_ ~to_ :: !leftover;
      true);
  RangeSet.update ~filter_from:r.from ~filter_to:r.to_
    ~filter:(fun ~from:_ ~to_:_ _ -> false)
    ~add:(List.rev !leftover) ranges

let add_range ranges r =
  let r = ref r in
  RangeSet.between ~from:!r.from ~to_:!r.to_ ranges (fun ~from ~to_ _ ->
      if from < !r.from then r := { from; to_ = !r.to_ };
      if to_ > !r.to_ then r := { from = !r.from; to_ };
      true);
  let r = !r in
  RangeSet.update ~filter_from:r.from ~filter_to:r.to_
    ~filter:(fun ~from:_ ~to_:_ _ -> false)
    ~add:[ Decoration.range highlight ~from:r.from ~to_:r.to_ ]
    ranges

let highlighted_ranges : Decoration.t RangeSet.t StateField.t =
  StateField.define
    (RangeSet.conv_of Decoration.conv)
    ~create:(fun _ -> Decoration.none)
    ~update:(fun ranges tr ->
      let ranges =
        RangeSet.map ranges (ChangeSet.desc (Transaction.changes tr))
      in
      List.fold_left
        (fun ranges e ->
          match StateEffect.value e add_highlight with
          | Some v -> add_range ranges v
          | None -> (
              match StateEffect.value e remove_highlight with
              | Some v -> cut_range ranges v
              | None -> ranges))
        ranges (Transaction.effects tr))
    ~provide:(fun field -> Facet.from EditorView.decorations field)

(*!invert*)

let invert_highlight =
  Facet.of_ Cm_commands.inverted_effects (fun tr ->
      let found = ref [] in
      List.iter
        (fun e ->
          match StateEffect.value e add_highlight with
          | Some v -> found := StateEffectType.of_ remove_highlight v :: !found
          | None -> (
              match StateEffect.value e remove_highlight with
              | Some v -> found := StateEffectType.of_ add_highlight v :: !found
              | None -> ()))
        (Transaction.effects tr);
      let ranges =
        EditorState.field (Transaction.start_state tr) highlighted_ranges
      in
      ChangeDesc.iter_changed_ranges
        (ChangeSet.desc (Transaction.changes tr))
        (fun ~from_a:ch_from ~to_a:ch_to ~from_b:_ ~to_b:_ ->
          RangeSet.between ~from:ch_from ~to_:ch_to ranges
            (fun ~from:r_from ~to_:r_to _ ->
              let from = max ch_from r_from and to_ = min ch_to r_to in
              if from < to_ then
                found :=
                  StateEffectType.of_ add_highlight { from; to_ } :: !found;
              true));
      List.rev !found)

(*!command*)

let highlight_selection view =
  EditorView.dispatch view
    (TransactionSpec.create
       ~effects:
         (EditorSelection.ranges (EditorState.selection (EditorView.state view))
         |> List.filter (fun r -> not (SelectionRange.empty r))
         |> List.map (fun r ->
                StateEffectType.of_ add_highlight
                  { from = SelectionRange.from r; to_ = SelectionRange.to_ r })
         )
       ());
  true

let unhighlight_selection view =
  let highlighted =
    EditorState.field (EditorView.state view) highlighted_ranges
  in
  let effects = ref [] in
  List.iter
    (fun sel ->
      let s_from = SelectionRange.from sel and s_to = SelectionRange.to_ sel in
      RangeSet.between ~from:s_from ~to_:s_to highlighted
        (fun ~from:r_from ~to_:r_to _ ->
          let from = max s_from r_from and to_ = min s_to r_to in
          if from < to_ then
            effects :=
              StateEffectType.of_ remove_highlight { from; to_ } :: !effects;
          true))
    (EditorSelection.ranges (EditorState.selection (EditorView.state view)));
  EditorView.dispatch view
    (TransactionSpec.create ~effects:(List.rev !effects) ());
  true

(*!extension*)

let highlight_keymap =
  Facet.of_ keymap
    [
      KeyBinding.create ~key:"Mod-h" ~run:highlight_selection ();
      KeyBinding.create ~key:"Shift-Mod-h" ~run:unhighlight_selection ();
    ]

let range_highlighting () =
  Extension.of_list
    [
      StateField.extension highlighted_ranges;
      invert_highlight;
      highlight_keymap;
    ]

(*!create*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           "Select something and press ctrl/cmd-h to highlight it\n\
            or shift-ctrl/cmd-h to remove highlighting.\n\
            Try undoing and redoing a highlight action.\n"
         ~extensions:
           (Extension.of_list
              [ range_highlighting (); Code_mirror.basic_setup ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()
