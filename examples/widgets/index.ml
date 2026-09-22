(* Widget decorations: elements drawn in the document. Pressing F2 adds
   a block widget under the cursor's line saying how long the line is.
   The widgets live in a state field of decorations, added by an effect
   whose position maps through later edits, so they stay with their
   lines as the text above them changes. *)

open Code_mirror
open Brr

let basic_setup = Code_mirror.basic_setup

(* The effect carries the position to decorate; [map] keeps it right when
   earlier text is inserted or deleted. *)
let add_note =
  State.StateEffect.define_ Jv.of_int Jv.to_int ~map:(fun pos changes ->
      Some (State.ChangeDesc.mapPos changes pos))

let note_widget text =
  View.WidgetType.make (fun () ->
      let el = El.div [ El.txt' text ] in
      El.set_inline_style (Jstr.v "color") (Jstr.v "#666") el;
      El.set_inline_style (Jstr.v "font-style") (Jstr.v "italic") el;
      El.set_inline_style (Jstr.v "padding-left") (Jstr.v "2em") el;
      el)

let decoration_conv =
  { Types.to_jv = View.Decoration.to_jv; of_jv = View.Decoration.of_jv }

let notes =
  State.StateField.define State.RangeSet.ty_to_jv
    (State.RangeSet.ty_of_jv decoration_conv)
    ~create:(fun _ -> View.Decoration.none)
    ~update:(fun set tr ->
      let set = State.RangeSet.map set (State.Transaction.changes tr) in
      List.fold_left
        (fun set e ->
          match State.StateEffect.value e add_note with
          | None -> set
          | Some pos ->
              let doc = State.EditorState.doc (State.Transaction.state tr) in
              let line = State.Text.line_at pos doc in
              let text =
                Printf.sprintf "line %d is %d characters long"
                  (State.Line.number line) (State.Line.length line)
              in
              let widget =
                View.Decoration.widget ~block:true ~side:1 (note_widget text)
              in
              State.RangeSet.update
                ~add:
                  [ View.Decoration.range ~from:(State.Line.to_ line) widget ]
                set)
        set
        (State.Transaction.effects tr))
    ~provide:(State.Facet.from View.EditorView.decorations)

let () =
  let note_here view =
    let state = View.EditorView.state view in
    let head =
      State.SelectionRange.head
        (List.hd
           (State.EditorSelection.ranges (State.EditorState.selection state)))
    in
    View.EditorView.dispatch view
      (State.TransactionSpec.create
         ~effects:[ State.StateEffect.of_ add_note head ]
         ());
    true
  in
  let keys =
    State.Facet.of_ Keymap.keymap (Keymap.create ~key:"F2" ~run:note_here ())
  in
  let config =
    State.EditorStateConfig.create
      ~doc:
        "Put the cursor on a line and press F2.\n\
         A note appears under the line.\n\
         Edit above a note: it stays with its line.\n"
      ~extensions:[ basic_setup; keys; State.StateField.extension notes ]
      ()
  in
  let state = State.EditorState.create ~config () in
  let _view =
    View.EditorView.create
      ~config:
        (View.EditorViewConfig.create ~state ~parent:(Document.body G.document)
           ())
      ()
  in
  ()
