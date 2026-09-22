(* Completion from a fixed list, a source of our own that answers
   differently depending on what precedes the cursor, close_brackets, and a
   snippet with fields to tab through. *)

open Brr
open Cm_state
open Cm_view
open Cm_autocomplete

(* -- source 1: a fixed list, one entry of which expands a snippet ------- *)

let for_snippet =
  snippet_completion
    ~template:"for (let ${i} = 0; ${i} < ${n}; ${i}++) {\n\t${}\n}"
    (Completion.create ~label:"for" ~detail:"for loop" ())

let fixed_source =
  complete_from_list
    (for_snippet
    :: List.map
         (fun w -> Completion.create ~label:w ())
         [ "function"; "return"; "const" ])

(* -- source 2: our own, answering differently depending on what comes
   right before the cursor - not something a fixed list can do -------- *)

let context_source : completion_source =
 fun ctx ->
  let state = CompletionContext.state ctx in
  let pos = CompletionContext.pos ctx in
  let before =
    if pos > 0 then EditorState.slice_doc ~from:(pos - 1) ~to_:pos state else ""
  in
  let names detail =
    List.map (fun w -> Completion.create ~label:w ~detail ())
  in
  match before with
  | "@" ->
      Fut.return
        (Some
           (CompletionResult.create ~from:pos
              ~options:(names "user" [ "alice"; "bob"; "carol" ])
              ()))
  | "#" ->
      Fut.return
        (Some
           (CompletionResult.create ~from:pos
              ~options:(names "tag" [ "urgent"; "bug"; "feature" ])
              ()))
  | _ -> Fut.return None

(* -- editor 1: the visible page ----------------------------------------- *)

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]

let extensions =
  Extension.of_list
    [
      autocompletion ~override:[ fixed_source; context_source ] ();
      Facet.of_ keymap completion_keymap;
      close_brackets ();
      Facet.of_ keymap close_brackets_keymap;
    ]

(* "f" as a starting prefix: matches both "function" and the "for" snippet
   completion, so the tooltip shows both routes at once. *)
let state =
  EditorState.create
    ~config:(EditorStateConfig.create ~doc:"f" ~extensions ())
    ()

let view =
  EditorView.create
    ~config:(EditorViewConfig.create ~state ~parent:container ())
    ()

let () =
  EditorView.dispatch view
    (TransactionSpec.create ~selection:(TransactionSpec.Cursor 1) ())

(* -- self-check ---------------------------------------------------- *)

open Example_check

let has_tooltip () =
  El.find_first_by_selector ~root:(EditorView.dom view)
    (Jstr.v ".cm-tooltip-autocomplete")
  <> None

(* -- editor 2, headless: close_brackets's own logic --------------------- *)

let close_brackets_state =
  EditorState.create
    ~config:
      (EditorStateConfig.create ~doc:"" ~extensions:(close_brackets ()) ())
    ()

(* -- a view for the snippet check, not on the page ------------------------ *)

let state3 = EditorState.create ~config:(EditorStateConfig.create ~doc:"" ()) ()

let view3 =
  EditorView.create ~config:(EditorViewConfig.create ~state:state3 ()) ()

let finish_checks (found : bool) =
  note
    "start_completion opens a tooltip listing both fixed-list options, \
     including the snippet-backed \"for\""
    (found
    && List.mem "for"
         (List.map Completion.label
            (current_completions (EditorView.state view))));

  Fut.await
    (context_source
       (CompletionContext.create
          (EditorState.create ~config:(EditorStateConfig.create ~doc:"@" ()) ())
          ~pos:1 ~explicit:true ()))
    (fun at_sign ->
      Fut.await
        (context_source
           (CompletionContext.create
              (EditorState.create
                 ~config:(EditorStateConfig.create ~doc:"#" ())
                 ())
              ~pos:1 ~explicit:true ()))
        (fun hash ->
          check
            "the context source completes users after '@' and tags after '#'"
            (fun () ->
              match (at_sign, hash) with
              | Some a, Some h ->
                  List.map Completion.label (CompletionResult.options a)
                  = [ "alice"; "bob"; "carol" ]
                  && List.map Completion.label (CompletionResult.options h)
                     = [ "urgent"; "bug"; "feature" ]
              | _ -> false);

          check "insert_bracket auto-inserts the closing bracket" (fun () ->
              match insert_bracket close_brackets_state ~bracket:"(" with
              | Some tr -> Text.to_string (Transaction.new_doc tr) = "()"
              | None -> false);

          let apply_snippet = snippet "x(${a}, ${b})" in
          apply_snippet view3 None ~from:0 ~to_:0;

          check "an expanded snippet's fields can be moved between" (fun () ->
              Text.to_string (EditorState.doc (EditorView.state view3))
              = "x(a, b)"
              && has_next_snippet_field (EditorView.state view3)
              &&
              let (_ : bool) = next_snippet_field view3 in
              match
                EditorSelection.ranges
                  (EditorState.selection (EditorView.state view3))
              with
              | [ r ] -> SelectionRange.from r = 5 && SelectionRange.to_ r = 6
              | _ -> false);

          report ()))

let () =
  keep [ view ];
  let (_ : bool) = start_completion view in
  Fut.await (wait_for ~tries:60 has_tooltip) finish_checks
