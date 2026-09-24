open Cm_state
open Cm_view
open Example_check

let breakpoints view =
  let out = ref [] in
  RangeSet.between
    (EditorState.field (EditorView.state view) Gutters.breakpoint_state)
    (fun ~from ~to_:_ _ ->
      out := from :: !out;
      true);
  List.rev !out

let () =
  keep [ Gutters.view ];
  let view = Gutters.view in
  check "blank lines get the ø marker" (fun () ->
      List.length
        (List.filter (( = ) "ø") (texts (by_class view "cm-gutterElement")))
      >= 3);
  check "toggling a breakpoint adds one, again removes it" (fun () ->
      Gutters.toggle_breakpoint view 5;
      let on = breakpoints view = [ 5 ] in
      Gutters.toggle_breakpoint view 5;
      on && breakpoints view = []);
  check "a breakpoint follows its line as text is inserted above" (fun () ->
      Gutters.toggle_breakpoint view 5;
      EditorView.dispatch view
        (TransactionSpec.create ~changes:(ChangeSpec.insert ~at:0 "New\n") ());
      breakpoints view = [ 9 ]);
  report ()
