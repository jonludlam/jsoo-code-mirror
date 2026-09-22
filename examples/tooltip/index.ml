(* A hover tooltip: point at a word and see the word, its length, and its
   position. [hover_tooltip]'s source is asynchronous
   ([Tooltip.t option Fut.t]); this one adds a short delay to make that
   honest, the way a source asking a language server would be. *)

open Brr
open Cm_state
open Cm_view

let doc_text = "hover over banana, or apple, to see its word.\nshort line"

let word_tooltip (view : EditorView.t) ~pos ~side:_ : Tooltip.t option Fut.t =
  match EditorState.word_at (EditorView.state view) pos with
  | None -> Fut.return None
  | Some range ->
      let from = SelectionRange.from range and to_ = SelectionRange.to_ range in
      let word = EditorState.slice_doc ~from ~to_ (EditorView.state view) in
      let create (_view : EditorView.t) : TooltipView.t =
        let dom =
          El.div
            ~at:At.[ class' (Jstr.v "cm-word-tooltip") ]
            [
              El.txt'
                (Printf.sprintf "%S, %d characters, at %d" word (to_ - from)
                   from);
            ]
        in
        TooltipView.create dom
      in
      (* The delay is what makes this a genuinely asynchronous source, as
         opposed to one that just happens to have a [Fut.t] in its type. *)
      Fut.bind (Fut.tick ~ms:50) (fun () ->
          Fut.return (Some (Tooltip.create ~pos:from ~end_:to_ ~create ())))

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]
let extensions = Extension.of_list [ hover_tooltip ~hover_time:50 word_tooltip ]
let editor_state_config = EditorStateConfig.create ~doc:doc_text ~extensions ()
let editor_state = EditorState.create ~config:editor_state_config ()

let view_config =
  EditorViewConfig.create ~state:editor_state ~parent:container ()

let view = EditorView.create ~config:view_config ()

(* -- self-check ------------------------------------------------------------
   Driving a real hover from script means synthesizing a "mousemove" at the
   exact screen coordinates of a character, dispatched on the DOM node
   CodeMirror's hover plugin tracks ([dom_at_pos] gives that node,
   [coords_for_char] its on-screen position), then waiting past both
   [hover_time] and the source's own delay -- which is what this does,
   rather than asserting on the source function in isolation. *)

open Example_check

let find_tooltip () =
  El.find_first_by_selector ~root:(Document.body G.document)
    (Jstr.v ".cm-word-tooltip")

let fire_mousemove_at pos =
  match EditorView.coords_for_char view pos with
  | None -> ()
  | Some (r : Rect.t) ->
      let dom, _offset = EditorView.dom_at_pos view pos in
      let cx = r.left +. 1. and cy = (r.top +. r.bottom) /. 2. in
      let ev =
        Jv.new'
          (Jv.get Jv.global "MouseEvent")
          [|
            Jv.of_string "mousemove";
            Jv.obj
              [|
                ("clientX", Jv.of_float cx);
                ("clientY", Jv.of_float cy);
                ("bubbles", Jv.true');
              |];
          |]
      in
      ignore (Ev.dispatch (Ev.of_jv ev) (El.as_target dom))

let () =
  keep [ view ];
  check "initial document renders" (fun () ->
      Jstr.find_sub ~sub:(Jstr.v "banana")
        (El.text_content (EditorView.content_dom view))
      <> None);

  let banana_pos = String.length "hover over " in
  fire_mousemove_at banana_pos;

  Fut.await
    (wait_for ~tries:60 (fun () -> find_tooltip () <> None))
    (fun found ->
      note
        "hovering a word shows the async tooltip with the word and its length"
        found;
      check "the tooltip reports the word under the pointer" (fun () ->
          match find_tooltip () with
          | None -> false
          | Some el ->
              Jstr.find_sub ~sub:(Jstr.v "banana") (El.text_content el) <> None);
      report ())
