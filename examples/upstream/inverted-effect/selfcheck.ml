open Cm_state
open Cm_view
open Example_check

let highlighted view =
  let state = EditorView.state view in
  let out = ref [] in
  RangeSet.between (EditorState.field state Inverted_effect.highlighted_ranges)
    (fun ~from ~to_ _ ->
      out := EditorState.slice_doc ~from ~to_ state :: !out;
      true);
  List.rev !out

let () =
  keep [ Inverted_effect.view ];
  let view = Inverted_effect.view in
  let from = String.length "Select " in
  let to_ = from + String.length "something" in
  check "Mod-h highlights the selection" (fun () ->
      select view from to_;
      ignore (press_mod view "h");
      highlighted view = [ "something" ]);
  check "undo removes the highlight, redo restores it" (fun () ->
      ignore (Cm_commands.undo view);
      let gone = highlighted view = [] in
      ignore (Cm_commands.redo view);
      gone && highlighted view = [ "something" ]);
  check "Shift-Mod-h cuts highlighting out of the middle" (fun () ->
      select view (from + 2) (from + 5);
      ignore (press_mod ~shift:true view "h");
      highlighted view = [ "so"; "hing" ]);
  check "undoing a deletion restores the highlight it took" (fun () ->
      EditorView.dispatch view
        (TransactionSpec.create
           ~changes:(ChangeSpec.delete ~from ~to_)
           ~user_event:"delete" ());
      let gone = highlighted view = [] in
      ignore (Cm_commands.undo view);
      gone && highlighted view = [ "so"; "hing" ]);
  report ()
