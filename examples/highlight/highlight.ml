(* Highlighting: pressing F1 underlines the current selection with a mark
   decoration. The effect that carries the marked range defines a [map] so
   the range tracks later edits (and disappears if its text is deleted).
   The StateField holding the decorations and the base_theme rule that
   styles them are not part of the initial configuration: they are spliced
   in on first use via [StateEffectType.append_config], the same effect
   CodeMirror's own reconfiguration examples use for this. *)

open Brr
open Code_mirror

type range = { from : int; to_ : int }

let range_conv : range State.Conv.t =
  {
    State.Conv.to_jv = (fun r -> Jv.of_list Jv.of_int [ r.from; r.to_ ]);
    of_jv =
      (fun jv ->
        match Jv.to_list Jv.to_int jv with
        | [ from; to_ ] -> { from; to_ }
        | _ -> State.Conv.invalid "highlight range" jv);
  }

let add_underline : range State.StateEffectType.t =
  State.StateEffectType.define range_conv ~map:(fun r changes ->
      match
        ( State.ChangeDesc.map_pos changes r.from,
          State.ChangeDesc.map_pos changes r.to_ )
      with
      | Some from, Some to_ when from < to_ -> Some { from; to_ }
      | _ -> None)

let underline_mark = View.Decoration.mark ~class_:"cm-underline" ()

let underline_field : View.Decoration.t State.RangeSet.t State.StateField.t =
  State.StateField.define
    (State.RangeSet.conv_of View.Decoration.conv)
    ~create:(fun _ -> State.RangeSet.empty View.Decoration.conv)
    ~update:(fun set tr ->
      let set =
        State.RangeSet.map set
          (State.ChangeSet.desc (State.Transaction.changes tr))
      in
      List.fold_left
        (fun set eff ->
          match State.StateEffect.value eff add_underline with
          | None -> set
          | Some { from; to_ } ->
              let deco = View.Decoration.range ~to_ underline_mark ~from in
              State.RangeSet.update ~add:[ deco ] set)
        set
        (State.Transaction.effects tr))
    ~provide:(fun field -> State.Facet.from View.EditorView.decorations field)

let underline_theme =
  View.EditorView.base_theme
    View.StyleSpec.
      [
        ( ".cm-underline",
          Rules
            [
              ("textDecoration", Value "underline 3px red");
              (* Browsers skip the underline where glyphs touch it, which at
                 this thickness leaves only fragments; draw it whole and
                 below the descenders. *)
              ("textDecorationSkipInk", Value "none");
              ("textUnderlineOffset", Value "3px");
            ] );
      ]

let field_and_theme =
  State.Extension.of_list
    [ State.StateField.extension underline_field; underline_theme ]

(* Underlines [from, to_), adding the field and its theme to the running
   configuration the first time they are needed. *)
let underline view ~from ~to_ =
  let state = View.EditorView.state view in
  let mark = State.StateEffectType.of_ add_underline { from; to_ } in
  let effects =
    match State.EditorState.field_opt state underline_field with
    | Some _ -> [ mark ]
    | None ->
        [
          State.StateEffectType.of_ State.StateEffectType.append_config
            field_and_theme;
          mark;
        ]
  in
  View.EditorView.dispatch view (State.TransactionSpec.create ~effects ())

let underline_selection view =
  let state = View.EditorView.state view in
  let ranges =
    State.EditorSelection.ranges (State.EditorState.selection state)
  in
  match List.filter (fun r -> not (State.SelectionRange.empty r)) ranges with
  | [] -> false
  | ranges ->
      List.iter
        (fun r ->
          underline view
            ~from:(State.SelectionRange.from r)
            ~to_:(State.SelectionRange.to_ r))
        ranges;
      true

let key_binding = View.KeyBinding.create ~key:"F1" ~run:underline_selection ()
let keymap_ext = State.Facet.of_ View.keymap [ key_binding ]
let container = El.div []
let () = El.append_children (Document.body G.document) [ container ]

let config =
  State.EditorStateConfig.create
    ~doc:"Select some text and press F1 to underline it.\nSome more text.\n"
    ~extensions:(State.Extension.of_list [ basic_setup; keymap_ext ])
    ()

let state = State.EditorState.create ~config ()

let view =
  View.EditorView.create
    ~config:(View.EditorViewConfig.create ~state ~parent:container ())
    ()

(* -- self-check -------------------------------------------------------- *)

open Example_check

let () =
  keep [ view ];
  check "the underline field is absent until first used" (fun () ->
      State.EditorState.field_opt (View.EditorView.state view) underline_field
      = None);

  check "underlining a range renders the mark decoration" (fun () ->
      underline view ~from:0 ~to_:6;
      El.find_first_by_selector ~root:(View.EditorView.dom view)
        (Jstr.v ".cm-underline")
      <> None);

  check "the base_theme rule for the underline is injected" (fun () ->
      El.find_by_tag_name (Jstr.v "style")
      |> List.exists (fun s ->
             Jstr.find_sub ~sub:(Jstr.v "cm-underline") (El.text_content s)
             <> None));

  report ()
