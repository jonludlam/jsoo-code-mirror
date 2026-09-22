(* Compartments: parts of the configuration that can be swapped at run
   time. Two buttons reconfigure two compartments: one holds the
   line-number gutter, whose formatter offsets the numbers, the other
   holds line wrapping. Each click dispatches a TransactionSpec carrying
   the effect Compartment.reconfigure returns.

   Deliberately not using basic_setup: it already installs line_numbers,
   and stacking a second copy through the compartment would just give two
   gutters instead of showing the compartment swapping the one that is
   there. *)

open Brr
open Cm_state
open Cm_view

let numbers = Compartment.make ()
let wrapping = Compartment.make ()
let offset = ref 0
let wrapped = ref true

let gutter () =
  line_numbers ~format_number:(fun n _state -> string_of_int (n + !offset)) ()

let wrap () =
  if !wrapped then EditorView.line_wrapping_extension else Extension.empty

let button label on_click =
  let b = El.button [ El.txt' label ] in
  ignore (Ev.listen Ev.click (fun _ -> on_click ()) (El.as_target b));
  b

let doc =
  "Line numbers start at 1 until you press the button; then this editor \
   numbers its lines as if it continued another.\n\
   Long lines wrap until the other button turns wrapping off. This line is \
   deliberately long, and the editor deliberately narrow, so that it has to \
   wrap: with wrapping off it runs past the right edge and the editor scrolls \
   sideways instead."

let config =
  EditorStateConfig.create ~doc
    ~extensions:
      (Extension.of_list
         [
           Compartment.of_ numbers (gutter ());
           Compartment.of_ wrapping (wrap ());
         ])
    ()

let state = EditorState.create ~config ()
let parent = El.div []
let () = El.set_inline_style (Jstr.v "max-width") (Jstr.v "40em") parent

let reconfigure view comp ext =
  EditorView.dispatch view
    (TransactionSpec.create ~effects:[ Compartment.reconfigure comp ext ] ())

let view =
  EditorView.create ~config:(EditorViewConfig.create ~state ~parent ()) ()

let number_from_100 () =
  offset := if !offset = 0 then 99 else 0;
  reconfigure view numbers (gutter ())

let toggle_wrapping () =
  wrapped := not !wrapped;
  reconfigure view wrapping (wrap ())

let controls =
  El.p
    [
      button "Number from 100" number_from_100;
      El.txt' " ";
      button "Toggle wrapping" toggle_wrapping;
    ]

let () = El.append_children (Document.body G.document) [ controls; parent ]

(* -- self-check -------------------------------------------------------- *)

open Example_check

let gutter_texts () =
  El.find_by_class ~root:(EditorView.dom view) (Jstr.v "cm-gutterElement")
  |> List.map El.text_content

(* [EditorView.line_wrapping] mirrors CodeMirror's [view.lineWrapping], which
   is measured from computed style during a (async, animation-frame)
   measure pass, so it does not update in the same tick as a dispatch.
   [EditorView.lineWrapping] (our [line_wrapping_extension]) itself is just
   [contentAttributes.of({class: "cm-lineWrapping"})]  (confirmed in
   @codemirror/view's dist/index.js), applied synchronously as a DOM
   attribute; checking that class directly is the reliable synchronous
   signal, so the self-check reads the DOM rather than the getter. *)
let wraps () =
  El.find_first_by_selector ~root:(EditorView.dom view)
    (Jstr.v ".cm-content.cm-lineWrapping")
  <> None

let () =
  keep [ view ];
  check "the gutter starts numbering at 1" (fun () ->
      List.exists (fun t -> Jstr.equal t (Jstr.v "1")) (gutter_texts ()));

  check "line wrapping starts on, per line_wrapping_extension" (fun () ->
      wraps ());

  check "reconfiguring the numbers compartment changes the gutter" (fun () ->
      number_from_100 ();
      List.exists (fun t -> Jstr.equal t (Jstr.v "100")) (gutter_texts ()));

  check "reconfiguring the wrapping compartment turns wrapping off" (fun () ->
      toggle_wrapping ();
      not (wraps ()));

  (* The restored state's gutter and wrapping read these refs, so they go
     back with it. *)
  offset := 0;
  wrapped := true;
  report ()
