(* This page's own module, before Cm_view's Tooltip hides it. *)
module Cursor = Tooltip
open Brr
open Cm_state
open Cm_view
open Example_check

let () =
  keep [ Cursor.view; Hover.view ];
  EditorView.dispatch Cursor.view
    (TransactionSpec.create ~selection:(TransactionSpec.Cursor 5) ());
  after 200 @@ fun () ->
  check "the cursor tooltip shows line and column" (fun () ->
      texts (by_class Cursor.view "cm-tooltip-cursor") = [ "1:5" ]);
  check "moving the cursor moves the tooltip's text" (fun () ->
      EditorView.dispatch Cursor.view
        (TransactionSpec.create ~selection:(TransactionSpec.Cursor 28) ());
      texts (by_class Cursor.view "cm-tooltip-cursor") = [ "2:2" ]);
  (* hover over "words" and wait for the hover delay *)
  let view = Hover.view in
  let pos = 11 in
  (match EditorView.coords_at_pos view pos with
  | Some r ->
      let init =
        Jv.obj
          [|
            ("clientX", Jv.of_float (Jv.to_float (Jv.get r "left") +. 2.));
            ("clientY", Jv.of_float (Jv.to_float (Jv.get r "top") +. 2.));
            ("bubbles", Jv.true');
          |]
      in
      let ev =
        Jv.new'
          (Jv.get Jv.global "MouseEvent")
          [| Jv.of_string "mousemove"; init |]
      in
      ignore
        (Ev.dispatch (Ev.of_jv ev) (El.as_target (EditorView.content_dom view)))
  | None -> ());
  after 700 @@ fun () ->
  check "hovering a word shows it in a tooltip" (fun () ->
      List.mem "words" (texts (by_class view "cm-tooltip")));
  report ()
