(* Widget decorations: elements drawn in the document. Pressing F2 adds a
   block widget under the cursor's line saying how long the line is. The
   widgets live in a StateField of decorations; on every update the
   RangeSet is mapped through the transaction's changes, so a widget stays
   attached to its line as text above it is edited. The button replaces
   the whole document with EditorView.set_doc: notes inside the replaced
   text go with it, but one at the very end of the document sits on the
   edge of the replacement, so it is mapped to the new end and stays. *)

open Brr
open Cm_state
open Cm_view

let note_widget text =
  WidgetType.make
    ~to_dom:(fun _view ->
      let el = El.div [ El.txt' text ] in
      El.set_inline_style (Jstr.v "color") (Jstr.v "#666") el;
      El.set_inline_style (Jstr.v "font-style") (Jstr.v "italic") el;
      El.set_inline_style (Jstr.v "padding-left") (Jstr.v "2em") el;
      El.set_class (Jstr.v "cm-note") true el;
      el)
    ()

(* The effect carries the position to decorate; [map] keeps it right when
   earlier text is inserted or deleted. *)
let add_note : int StateEffectType.t =
  StateEffectType.define Conv.int ~map:(fun pos changes ->
      ChangeDesc.map_pos changes pos)

let notes : Decoration.t RangeSet.t StateField.t =
  StateField.define
    (RangeSet.conv_of Decoration.conv)
    ~create:(fun _ -> RangeSet.empty Decoration.conv)
    ~update:(fun set tr ->
      let set = RangeSet.map set (ChangeSet.desc (Transaction.changes tr)) in
      List.fold_left
        (fun set eff ->
          match StateEffect.value eff add_note with
          | None -> set
          | Some pos ->
              let doc = EditorState.doc (Transaction.state tr) in
              let line = Text.line_at doc pos in
              let text =
                Printf.sprintf "line %d is %d characters long"
                  (Line.number line) (Line.length line)
              in
              let widget =
                Decoration.widget ~block:true ~side:1 (note_widget text)
              in
              let deco = Decoration.range widget ~from:(Line.to_ line) in
              RangeSet.update ~add:[ deco ] set)
        set (Transaction.effects tr))
    ~provide:(fun field -> Facet.from EditorView.decorations field)

let note_here view =
  let state = EditorView.state view in
  let head =
    SelectionRange.head (EditorSelection.main (EditorState.selection state))
  in
  EditorView.dispatch view
    (TransactionSpec.create ~effects:[ StateEffectType.of_ add_note head ] ());
  true

let keys = Facet.of_ keymap [ KeyBinding.create ~key:"F2" ~run:note_here () ]
let container = El.div []
let () = El.append_children (Document.body G.document) [ container ]

let initial_doc =
  "Put the cursor on a line and press F2.\n\
   A note appears under the line.\n\
   Edit above a note: it stays with its line.\n"

let config =
  EditorStateConfig.create ~doc:initial_doc
    ~extensions:(Extension.of_list [ keys; StateField.extension notes ])
    ()

let state = EditorState.create ~config ()

let view =
  EditorView.create
    ~config:(EditorViewConfig.create ~state ~parent:container ())
    ()

let reset = El.button [ El.txt' "Reset document" ]

let () =
  ignore
    (Ev.listen Ev.click
       (fun _ -> EditorView.set_doc view initial_doc)
       (El.as_target reset));
  El.append_children (Document.body G.document) [ reset ]

(* -- self-check -------------------------------------------------------- *)

open Example_check

let note_texts () =
  El.find_by_class ~root:(EditorView.dom view) (Jstr.v "cm-note")
  |> List.map (fun e -> Jstr.to_string (El.text_content e))

let () =
  keep [ view ];
  check "F2 adds a block widget describing the current line" (fun () ->
      ignore (note_here view);
      List.exists
        (fun t -> Jstr.find_sub ~sub:(Jstr.v "line 1 is") (Jstr.v t) <> None)
        (note_texts ()));

  check "the widget's position maps through an edit above it" (fun () ->
      let before = List.length (note_texts ()) in
      EditorView.dispatch view
        (TransactionSpec.create ~changes:(ChangeSpec.insert ~at:0 "x") ());
      List.length (note_texts ()) = before);

  check "pressing F2 again on another line adds another widget" (fun () ->
      let before = List.length (note_texts ()) in
      EditorView.dispatch view
        (TransactionSpec.create
           ~selection:
             (TransactionSpec.Cursor
                (Text.length (EditorState.doc (EditorView.state view))))
           ());
      ignore (note_here view);
      List.length (note_texts ()) = before + 1);

  check "reset drops the notes inside the document, keeps the one at its end"
    (fun () ->
      let before = List.length (note_texts ()) in
      El.click reset;
      Text.to_string (EditorState.doc (EditorView.state view)) = initial_doc
      && before > 1
      && note_texts () = [ "line 4 is 0 characters long" ]);

  report ()
