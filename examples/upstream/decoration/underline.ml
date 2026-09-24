(* https://codemirror.net/examples/decoration/, its first editor *)

open Brr
open Cm_state
open Cm_view

(*!underlineState*)

type range = { from : int; to_ : int }

let add_underline =
  StateEffectType.define
    ~map:(fun { from; to_ } change ->
      match (ChangeDesc.map_pos change from, ChangeDesc.map_pos change to_) with
      | Some from, Some to_ -> Some { from; to_ }
      | _ -> None)
    {
      Conv.to_jv =
        (fun r ->
          Jv.obj [| ("from", Jv.of_int r.from); ("to", Jv.of_int r.to_) |]);
      of_jv = (fun o -> { from = Jv.Int.get o "from"; to_ = Jv.Int.get o "to" });
    }

(* Upstream defines this after the field that uses it; OCaml needs it
   first. *)
let underline_mark = Decoration.mark ~class_:"cm-underline" ()

let underline_field : Decoration.t RangeSet.t StateField.t =
  StateField.define
    (RangeSet.conv_of Decoration.conv)
    ~create:(fun _ -> Decoration.none)
    ~update:(fun underlines tr ->
      let underlines =
        RangeSet.map underlines (ChangeSet.desc (Transaction.changes tr))
      in
      List.fold_left
        (fun underlines e ->
          match StateEffect.value e add_underline with
          | Some v ->
              RangeSet.update
                ~add:[ Decoration.range underline_mark ~from:v.from ~to_:v.to_ ]
                underlines
          | None -> underlines)
        underlines (Transaction.effects tr))
    ~provide:(fun f -> Facet.from EditorView.decorations f)

(*!underlineSelection*)

let underline_theme =
  EditorView.base_theme
    StyleSpec.
      [
        ( ".cm-underline",
          Rules [ ("textDecoration", Value "underline 3px red") ] );
      ]

let underline_selection view =
  let effects =
    EditorSelection.ranges (EditorState.selection (EditorView.state view))
    |> List.filter (fun r -> not (SelectionRange.empty r))
    |> List.map (fun r ->
           StateEffectType.of_ add_underline
             { from = SelectionRange.from r; to_ = SelectionRange.to_ r })
  in
  if effects = [] then false
  else
    let effects =
      if EditorState.field_opt (EditorView.state view) underline_field = None
      then
        effects
        @ [
            StateEffectType.of_ StateEffectType.append_config
              (Extension.of_list
                 [ StateField.extension underline_field; underline_theme ]);
          ]
      else effects
    in
    EditorView.dispatch view (TransactionSpec.create ~effects ());
    true

(*!underlineKeymap*)

let underline_keymap =
  Facet.of_ keymap
    [
      KeyBinding.create ~key:"Mod-h" ~prevent_default:true
        ~run:underline_selection ();
    ]

(*!create*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           "Select text and press Ctrl-h (Cmd-h) to add an underline\nto it.\n"
         ~extensions:
           (Extension.of_list [ underline_keymap; Code_mirror.basic_setup ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor-underline")))
         ())
    ()
