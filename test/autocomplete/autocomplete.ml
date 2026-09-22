(* Browser exerciser for code-mirror.autocomplete: creates a real editor
   with [autocompletion] and a [complete_from_list] source, triggers
   completion with [start_completion], waits for the (asynchronous)
   completion tooltip to appear in the DOM, and checks [current_completions]/
   [completion_status]/[accept_completion] against it; then, with no DOM
   involved, checks a hand-written completion source returning a
   [CompletionResult] built by hand, [close_brackets]'s [insert_bracket],
   and a snippet's field navigation. Not a Playwright runner: this page just
   runs itself and reports through [window.autocompleteTestResults], the
   same shape test/view, test/search and test/lint use. *)

open Brr
open Cm_state
open Cm_view
open Cm_autocomplete

(* -- bookkeeping ---------------------------------------------------- *)

let details = ref []
let check name f = details := (name, try f () with _ -> false) :: !details
let note name ok = details := (name, ok) :: !details

let jv_of_pair (name, ok) =
  Jv.obj [| ("name", Jv.of_string name); ("ok", Jv.of_bool ok) |]

let report () =
  let details = List.rev !details in
  let total = List.length details in
  let passed = List.length (List.filter (fun (_, ok) -> ok) details) in
  let failed = total - passed in
  let result =
    Jv.obj
      [|
        ("total", Jv.of_int total);
        ("passed", Jv.of_int passed);
        ("failed", Jv.of_int failed);
        ("details", Jv.of_list jv_of_pair details);
        ("done", Jv.true');
      |]
  in
  Jv.set Jv.global "autocompleteTestResults" result

let contains ~sub s = Jstr.find_sub ~sub:(Jstr.v sub) (Jstr.v s) <> None

let rec wait_for ~tries (pred : unit -> bool) : bool Fut.t =
  if pred () then Fut.return true
  else if tries <= 0 then Fut.return false
  else Fut.bind (Fut.tick ~ms:50) (fun () -> wait_for ~tries:(tries - 1) pred)

(* -- editor 1: autocompletion, driven by a complete_from_list source ---- *)

let words = [ "hello"; "help"; "helicopter" ]
let container1 = El.div ~at:At.[ id (Jstr.v "editor1") ] []
let () = El.append_children (Document.body G.document) [ container1 ]

let source =
  complete_from_list (List.map (fun w -> Completion.create ~label:w ()) words)

(* close_on_blur:false because creating the later editors takes the focus,
   and a blurred editor closes its completion. *)
let extensions1 =
  Extension.of_list
    [
      autocompletion ~override:[ source ] ~close_on_blur:false ();
      Facet.of_ keymap completion_keymap;
    ]

let state1_config =
  EditorStateConfig.create ~doc:"he" ~extensions:extensions1 ()

let state1 = EditorState.create ~config:state1_config ()

let view1 =
  EditorView.create
    ~config:(EditorViewConfig.create ~state:state1 ~parent:container1 ())
    ()

(* put the cursor after "he", so the source has a prefix to match *)
let () =
  EditorView.dispatch view1
    (TransactionSpec.create ~selection:(TransactionSpec.Cursor 2) ())

let has_tooltip () =
  El.find_first_by_selector ~root:(EditorView.dom view1)
    (Jstr.v ".cm-tooltip-autocomplete")
  <> None

(* -- editor 2: exercises insert_bracket, close_brackets's own logic ----- *)

let close_brackets_state =
  EditorState.create
    ~config:
      (EditorStateConfig.create ~doc:"" ~extensions:(close_brackets ()) ())
    ()

(* -- editor 3: a snippet with two named fields --------------------------- *)

let container3 = El.div ~at:At.[ id (Jstr.v "editor3") ] []
let () = El.append_children (Document.body G.document) [ container3 ]
let state3 = EditorState.create ~config:(EditorStateConfig.create ~doc:"" ()) ()

let view3 =
  EditorView.create
    ~config:(EditorViewConfig.create ~state:state3 ~parent:container3 ())
    ()

(* -- a completion source of our own, returning a hand-built CompletionResult
   -- exercised directly against a CompletionContext, no DOM involved --- *)

let hand_source : completion_source =
 fun ctx ->
  Fut.return
    (Some
       (CompletionResult.create
          ~from:(CompletionContext.pos ctx)
          ~options:
            [
              Completion.create ~label:"custom-option" ~detail:"built by hand"
                ();
            ]
          ()))

let hand_ctx_state =
  EditorState.create ~config:(EditorStateConfig.create ~doc:"xy" ()) ()

let hand_ctx = CompletionContext.create hand_ctx_state ~pos:2 ~explicit:true ()

(* -- run the checks; the async ones are chained after the initial wait, as
   named continuations rather than one deeply-nested expression --------- *)

let stage3 () =
  check
    "insert_bracket auto-inserts the closing bracket for an editor with \
     close_brackets" (fun () ->
      match insert_bracket close_brackets_state ~bracket:"(" with
      | None -> false
      | Some tr -> (
          Text.to_string (Transaction.new_doc tr) = "()"
          &&
          match EditorSelection.ranges (Transaction.new_selection tr) with
          | [ r ] -> SelectionRange.from r = 1 && SelectionRange.to_ r = 1
          | _ -> false));

  let apply_snippet = snippet "foo(${a}, ${b})" in
  EditorView.focus view3;
  apply_snippet view3 None ~from:0 ~to_:0;

  check "snippet inserts its literal text with the fields' defaults" (fun () ->
      Text.to_string (EditorState.doc (EditorView.state view3)) = "foo(a, b)");

  check "has_next_snippet_field is true right after expansion" (fun () ->
      has_next_snippet_field (EditorView.state view3));

  check "next_snippet_field moves the selection to the second field" (fun () ->
      let (_ : bool) = next_snippet_field view3 in
      match
        EditorSelection.ranges (EditorState.selection (EditorView.state view3))
      with
      | [ r ] -> SelectionRange.from r = 7 && SelectionRange.to_ r = 8
      | _ -> false);

  (* CodeMirror deactivates the snippet once the selection reaches the last
     field, so on the second of two fields neither direction is available.
     Checked against the JavaScript directly, not a quirk of the binding. *)
  check "the snippet deactivates on reaching its last field" (fun () ->
      (not (has_next_snippet_field (EditorView.state view3)))
      && not (has_prev_snippet_field (EditorView.state view3)));

  check "clear_snippet deactivates the snippet's fields" (fun () ->
      let (_ : bool) = clear_snippet view3 in
      not (has_next_snippet_field (EditorView.state view3)));

  check "snippet_keymap's default bindings decode to a non-empty list"
    (fun () ->
      List.length (EditorState.facet (EditorState.create ()) snippet_keymap) > 0);

  report ()

let stage2 (result : CompletionResult.t option) =
  check "a hand-built CompletionResult, from our own source, round-trips"
    (fun () ->
      match result with
      | None -> false
      | Some r -> (
          CompletionResult.from r = 2
          &&
          match CompletionResult.options r with
          | [ c ] ->
              Completion.label c = "custom-option"
              && Completion.detail c = Some "built by hand"
          | _ -> false));
  stage3 ()

let stage1 (found : bool) =
  note "start_completion opens the completion tooltip (async)" found;

  check "completion_status is `Active once the tooltip is open" (fun () ->
      completion_status (EditorView.state view1) = Some `Active);

  check "current_completions lists our three options" (fun () ->
      let labels =
        List.map Completion.label (current_completions (EditorView.state view1))
      in
      List.for_all (fun w -> List.mem w labels) words);

  check "the tooltip renders one DOM option per completion" (fun () ->
      let n =
        El.fold_find_by_selector ~root:(EditorView.dom view1)
          (fun _ n -> n + 1)
          (Jstr.v ".cm-completionLabel")
          0
      in
      n = List.length words);

  (* accept_completion refuses for the first interaction_delay milliseconds
     after the completion opens (75 by default), and only acts on a focused
     view, which creating the later editors took away. So: refocus, wait out
     the delay, then accept. *)
  let accept_then_continue () =
    EditorView.focus view1;
    Fut.await (Fut.tick ~ms:200) (fun () ->
        check "accept_completion inserts the selected completion's text"
          (fun () ->
            let (_ : bool) = accept_completion view1 in
            let doc =
              Text.to_string (EditorState.doc (EditorView.state view1))
            in
            List.mem doc words);
        Fut.await (hand_source hand_ctx) stage2)
  in
  accept_then_continue ()

let () =
  check "editor1's initial document renders \"he\"" (fun () ->
      contains ~sub:"he"
        (Jstr.to_string (El.text_content (EditorView.content_dom view1))));

  let (_ : bool) = start_completion view1 in

  Fut.await (wait_for ~tries:60 has_tooltip) stage1
