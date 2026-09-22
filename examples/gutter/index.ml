(* A gutter of our own, beside the line numbers: a GutterMarker on every
   line containing a chosen word, held in a RangeSet that is recomputed
   whenever the document changes. This is the same shape CodeMirror's own
   docs use for a breakpoint gutter; ours marks a word instead of a
   click. *)

open Brr
open Cm_state
open Cm_view

let word = "TODO"
let contains ~sub s = Jstr.find_sub ~sub:(Jstr.v sub) (Jstr.v s) <> None

let marker =
  GutterMarker.make ~element_class:"cm-todo-marker"
    ~to_dom:(fun _view -> El.span [ El.txt' "\xe2\x97\x8f" ])
    ()

let marks_of_doc state =
  let text = EditorState.doc state in
  let ranges = ref [] in
  for n = 1 to Text.lines text do
    let line = Text.line text n in
    if contains ~sub:word (Line.text line) then
      ranges := GutterMarker.range marker ~from:(Line.from line) :: !ranges
  done;
  RangeSet.of_ GutterMarker.conv (List.rev !ranges)

let todo_marks : GutterMarker.t RangeSet.t StateField.t =
  StateField.define (RangeSet.conv_of GutterMarker.conv) ~create:marks_of_doc
    ~update:(fun set tr ->
      if Transaction.doc_changed tr then marks_of_doc (Transaction.state tr)
      else set)

let todo_gutter =
  gutter ~class_:"cm-todo-gutter"
    ~markers:(fun view -> EditorState.field (EditorView.state view) todo_marks)
    ()

let doc_text =
  "TODO: write the introduction\n\
   this line is done, nothing to see\n\
   TODO: fill in the examples\n\
   also finished\n\
   plain line"

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]

let extensions =
  Extension.of_list
    [ StateField.extension todo_marks; todo_gutter; line_numbers () ]

let editor_state_config = EditorStateConfig.create ~doc:doc_text ~extensions ()
let editor_state = EditorState.create ~config:editor_state_config ()

let view_config =
  EditorViewConfig.create ~state:editor_state ~parent:container ()

let view = EditorView.create ~config:view_config ()

(* -- self-check ------------------------------------------------------------ *)

open Example_check

let marker_count () =
  List.length
    (El.find_by_class ~root:(EditorView.dom view) (Jstr.v "cm-todo-marker"))

let () =
  keep [ view ];
  check "initial document renders" (fun () ->
      contains ~sub:"TODO"
        (Jstr.to_string (El.text_content (EditorView.content_dom view))));

  check "the gutter marks the two lines that contain TODO" (fun () ->
      marker_count () = 2);

  check "adding \"TODO\" to a plain line adds a marker" (fun () ->
      (* "plain line" is the last line; insert "TODO " at its start. *)
      let doc = Text.to_string (EditorState.doc (EditorView.state view)) in
      let at = String.length doc - String.length "plain line" in
      EditorView.dispatch view
        (TransactionSpec.create ~changes:(ChangeSpec.insert ~at "TODO ") ());
      marker_count () = 3);

  check "removing the word again removes its marker" (fun () ->
      let doc = Text.to_string (EditorState.doc (EditorView.state view)) in
      let at = String.length doc - String.length "TODO plain line" in
      EditorView.dispatch view
        (TransactionSpec.create
           ~changes:(ChangeSpec.delete ~from:at ~to_:(at + 5))
           ());
      marker_count () = 2);

  report ()
