open Cm_view
open Example_check

let () =
  (* CodeMirror reads the direction when it first measures a view *)
  after 100 @@ fun () ->
  check "the editor in an rtl parent runs right to left" (fun () ->
      EditorView.text_direction Bidi.rtl_view = Direction.Rtl);
  check "bidi_isolates isolates the HTML tags left to right" (fun () ->
      by_class Bidi.isolate_view "cm-iso"
      |> List.filter (fun el ->
             Brr.El.at (Jstr.v "dir") el = Some (Jstr.v "ltr"))
      |> texts
      = [ "<span class=\"blue\">"; "</span>" ]);
  report ()
