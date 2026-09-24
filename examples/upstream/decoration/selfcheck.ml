open Brr
open Cm_state
open Cm_view
open Example_check

let () =
  keep [ Underline.view; Checkbox.view; Placeholder.view ];
  let u = Underline.view in
  check "Mod-h underlines the selection" (fun () ->
      select u 7 11;
      ignore (press_mod u "h");
      texts (by_class u "cm-underline") = [ "text" ]);
  check "the field was added by appendConfig on first use" (fun () ->
      EditorState.field_opt (EditorView.state u) Underline.underline_field
      <> None);
  let c = Checkbox.view in
  let boxes () =
    El.find_by_tag_name ~root:(EditorView.content_dom c) (Jstr.v "input")
    |> List.map (fun b -> Jv.Bool.get (El.to_jv b) "checked")
  in
  check "each boolean gets a checkbox showing its value" (fun () ->
      boxes () = [ true; false ]);
  check "clicking a checkbox flips the boolean" (fun () ->
      match
        El.find_by_tag_name ~root:(EditorView.content_dom c) (Jstr.v "input")
      with
      | b :: _ ->
          let ev =
            Jv.new'
              (Jv.get Jv.global "MouseEvent")
              [| Jv.of_string "mousedown"; Jv.obj [| ("bubbles", Jv.true') |] |]
          in
          ignore (Ev.dispatch (Ev.of_jv ev) (El.as_target b));
          contains ~sub:"let value = false" (text c)
          && boxes () = [ false; false ]
      | [] -> false);
  let p = Placeholder.view in
  check "each [[name]] is drawn as a widget" (fun () ->
      El.find_by_tag_name ~root:(EditorView.content_dom p) (Jstr.v "span")
      |> texts
      |> List.filter (fun t -> List.mem t [ "name"; "item"; "order" ])
      = [ "name"; "item"; "order" ]);
  check "the placeholders are atomic: the cursor jumps over one" (fun () ->
      EditorView.dispatch p
        (TransactionSpec.create ~selection:(TransactionSpec.Cursor 5) ());
      ignore (Cm_commands.cursor_char_right p);
      SelectionRange.head
        (EditorSelection.main (EditorState.selection (EditorView.state p)))
      = String.length "Dear [[name]]");
  report ()
