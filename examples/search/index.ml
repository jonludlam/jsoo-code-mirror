(* @codemirror/search's headline features: find next/previous and
   replace-all driven from two text inputs and buttons, and
   [highlight_selection_matches] marking the other occurrences of whatever
   is selected. [search_keymap] and [panels ()] are also wired in, so
   CodeMirror's own search panel is still reachable (Mod-f) alongside our
   buttons. *)

open Brr
open Cm_state
open Cm_view
open Cm_search

let doc_text =
  "the quick fox jumps over the lazy fox\n\
   a fox and a hound trot by\n\
   gonefoo appears three times: gonefoo gonefoo"

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]

let extensions =
  Extension.of_list
    [
      search ();
      highlight_selection_matches ();
      panels ();
      Facet.of_ keymap search_keymap;
    ]

let editor_state_config = EditorStateConfig.create ~doc:doc_text ~extensions ()
let editor_state = EditorState.create ~config:editor_state_config ()

let view_config =
  EditorViewConfig.create ~state:editor_state ~parent:container ()

let view = EditorView.create ~config:view_config ()

(* -- controls: two inputs, and the commands driven from them ------------ *)

let query_input =
  El.input ~at:At.[ v (Jstr.v "size") (Jstr.v "10"); value (Jstr.v "fox") ] ()

let replace_input =
  El.input ~at:At.[ v (Jstr.v "size") (Jstr.v "10"); value (Jstr.v "FOX") ] ()

(* [set_search_query] only takes effect once the search state exists,
   which [search ()] above already ensures; dispatching it before each
   command is what CodeMirror's own panel does as you type. *)
let sync_query () =
  let q =
    SearchQuery.create
      ~search:(Jstr.to_string (El.prop El.Prop.value query_input))
      ~replace:(Jstr.to_string (El.prop El.Prop.value replace_input))
      ()
  in
  EditorView.dispatch view
    (TransactionSpec.create
       ~effects:[ StateEffectType.of_ set_search_query q ]
       ())

let button label f =
  let b = El.button [ El.txt' label ] in
  ignore (Ev.listen Ev.click (fun _ -> f ()) (El.as_target b));
  b

let find_next_button =
  button "Find next" (fun () ->
      sync_query ();
      ignore (find_next view))

let find_prev_button =
  button "Find previous" (fun () ->
      sync_query ();
      ignore (find_previous view))

let replace_all_button =
  button "Replace all" (fun () ->
      sync_query ();
      ignore (replace_all view))

let controls =
  El.p
    [
      El.txt' "search ";
      query_input;
      El.txt' " replace ";
      replace_input;
      El.txt' " ";
      find_next_button;
      El.txt' " ";
      find_prev_button;
      El.txt' " ";
      replace_all_button;
    ]

let () = El.append_children (Document.body G.document) [ controls ]

(* -- self-check ------------------------------------------------------------ *)

let details = ref []
let check name f = details := (name, try f () with _ -> false) :: !details

let jv_of_pair (name, ok) =
  Jv.obj [| ("name", Jv.of_string name); ("ok", Jv.of_bool ok) |]

let report () =
  let details = List.rev !details in
  let total = List.length details in
  let passed = List.length (List.filter (fun (_, ok) -> ok) details) in
  Jv.set Jv.global "exampleResults"
    (Jv.obj
       [|
         ("total", Jv.of_int total);
         ("passed", Jv.of_int passed);
         ("failed", Jv.of_int (total - passed));
         ("details", Jv.of_list jv_of_pair details);
         ("done", Jv.true');
       |])

let doc_string () = Text.to_string (EditorState.doc (EditorView.state view))

let count_occurrences ~sub s =
  let sub_len = String.length sub and len = String.length s in
  let rec go i n =
    if i + sub_len > len then n
    else go (i + 1) (if String.sub s i sub_len = sub then n + 1 else n)
  in
  go 0 0

let main_selection_text () =
  let sel =
    EditorSelection.main (EditorState.selection (EditorView.state view))
  in
  EditorState.slice_doc ~from:(SelectionRange.from sel)
    ~to_:(SelectionRange.to_ sel) (EditorView.state view)

let set_cursor pos =
  EditorView.dispatch view
    (TransactionSpec.create ~selection:(TransactionSpec.Cursor pos) ())

let set_range ~anchor ~head =
  EditorView.dispatch view
    (TransactionSpec.create
       ~selection:(TransactionSpec.Anchor_head { anchor; head })
       ())

let () =
  check "initial document renders" (fun () ->
      Jstr.find_sub ~sub:(Jstr.v "fox")
        (El.text_content (EditorView.content_dom view))
      <> None);

  check "the Find next / Find previous buttons move the selection onto a match"
    (fun () ->
      set_cursor 0;
      El.click find_next_button;
      let forward_ok =
        String.lowercase_ascii (main_selection_text ()) = "fox"
      in
      set_cursor (String.length (doc_string ()));
      El.click find_prev_button;
      let backward_ok =
        String.lowercase_ascii (main_selection_text ()) = "fox"
      in
      forward_ok && backward_ok);

  check
    "selecting a word marks its other occurrences (highlight_selection_matches)"
    (fun () ->
      (* "fox" starts at position 10 on the first line: "the quick " is
         ten characters. *)
      set_range ~anchor:10 ~head:13;
      El.find_first_by_selector ~root:(EditorView.dom view)
        (Jstr.v ".cm-selectionMatch")
      <> None);

  check
    "Replace all, driven by the button, replaces every match with the typed \
     replacement" (fun () ->
      El.set_prop El.Prop.value (Jstr.v "gonefoo") query_input;
      El.set_prop El.Prop.value (Jstr.v "GONE") replace_input;
      El.click replace_all_button;
      let d = doc_string () in
      count_occurrences ~sub:"GONE" d = 3
      && Jstr.find_sub ~sub:(Jstr.v "gonefoo") (Jstr.v d) = None);

  report ()
