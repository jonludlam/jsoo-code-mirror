(* Browser exerciser for code-mirror.search: creates a real editor with the
   search extension, drives its commands, and checks the SearchQuery/
   SearchCursor/RegExpCursor bindings directly against a document. Not a
   Playwright runner: this page just runs itself and reports through
   [window.searchTestResults], the same shape test/view uses. *)

open Brr
open Cm_state
open Cm_view
open Cm_search

(* -- bookkeeping ---------------------------------------------------- *)

let details = ref []

let check name f =
  let ok = try f () with _ -> false in
  details := (name, ok) :: !details

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
  Jv.set Jv.global "searchTestResults" result

(* -- small string helpers, to locate fixture words without hard-coding
   offsets --------------------------------------------------------- *)

let find_index ~sub s =
  let sub_len = String.length sub and len = String.length s in
  let rec go i =
    if i + sub_len > len then None
    else if String.sub s i sub_len = sub then Some i
    else go (i + 1)
  in
  go 0

let find_all_indices ~sub s =
  let sub_len = String.length sub and len = String.length s in
  let rec go i acc =
    if i + sub_len > len then List.rev acc
    else if String.sub s i sub_len = sub then go (i + 1) (i :: acc)
    else go (i + 1) acc
  in
  go 0 []

let count_occurrences ~sub s = List.length (find_all_indices ~sub s)

(* -- fixture document, one distinct word per command under test so tests
   don't disturb each other's fixtures ------------------------------- *)

let doc_text =
  "needle alpha needle beta needle gamma target delta dup epsilon dup zeta \
   gonefoo eta gonefoo theta gonefoo iota"

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]

let extensions =
  Extension.of_list
    [
      search ();
      highlight_selection_matches ();
      panels ();
      Facet.of_ keymap search_keymap;
      (* select_next_occurrence needs multiple selection ranges; CodeMirror
         collapses a transaction's selection back to one range unless this
         is on. *)
      Facet.of_ EditorState.allow_multiple_selections true;
    ]

let editor_state_config = EditorStateConfig.create ~doc:doc_text ~extensions ()
let editor_state = EditorState.create ~config:editor_state_config ()

let view_config =
  EditorViewConfig.create ~state:editor_state ~parent:container ()

let view = EditorView.create ~config:view_config ()

(* -- helpers over the live view -------------------------------------- *)

let doc_string () = Text.to_string (EditorState.doc (EditorView.state view))

let set_cursor pos =
  EditorView.dispatch view
    (TransactionSpec.create ~selection:(TransactionSpec.Cursor pos) ())

let set_range ~anchor ~head =
  EditorView.dispatch view
    (TransactionSpec.create
       ~selection:(TransactionSpec.Anchor_head { anchor; head })
       ())

let main_selection_text () =
  let sel =
    EditorSelection.main (EditorState.selection (EditorView.state view))
  in
  EditorState.slice_doc ~from:(SelectionRange.from sel)
    ~to_:(SelectionRange.to_ sel) (EditorView.state view)

let selection_range_count () =
  List.length
    (EditorSelection.ranges (EditorState.selection (EditorView.state view)))

let dispatch_query q =
  let eff = StateEffectType.of_ set_search_query q in
  EditorView.dispatch view (TransactionSpec.create ~effects:[ eff ] ())

(* -- checks ----------------------------------------------------------- *)

let () =
  check "initial document renders" (fun () ->
      let t = El.text_content (EditorView.content_dom view) in
      Jstr.find_sub ~sub:(Jstr.v "needle") t <> None);

  check "set_search_query / get_search_query round-trip" (fun () ->
      let q = SearchQuery.create ~search:"needle" ~case_sensitive:true () in
      dispatch_query q;
      let q2 = get_search_query (EditorView.state view) in
      SearchQuery.search q2 = "needle"
      && SearchQuery.case_sensitive q2
      && SearchQuery.valid q2);

  check "find_next moves the selection onto a match" (fun () ->
      let q = SearchQuery.create ~search:"needle" () in
      dispatch_query q;
      set_cursor 0;
      ignore (find_next view);
      String.lowercase_ascii (main_selection_text ()) = "needle");

  check "find_previous moves the selection onto a match" (fun () ->
      let target_pos = Option.get (find_index ~sub:"target" doc_text) in
      set_cursor target_pos;
      ignore (find_previous view);
      String.lowercase_ascii (main_selection_text ()) = "needle");

  check "select_next_occurrence adds a selection range" (fun () ->
      let pos = Option.get (find_index ~sub:"needle" doc_text) in
      set_range ~anchor:pos ~head:(pos + 6);
      let before = selection_range_count () in
      ignore (select_next_occurrence view);
      selection_range_count () > before);

  check "replace_next changes the document" (fun () ->
      (* replace_next only replaces when the selection already sits on a
         match; otherwise (as after set_cursor here) it behaves like
         find_next and just moves there. So: move onto the match first,
         then replace it. *)
      let q = SearchQuery.create ~search:"target" ~replace:"REPLACED" () in
      dispatch_query q;
      set_cursor 0;
      ignore (find_next view);
      ignore (replace_next view);
      let d = doc_string () in
      find_index ~sub:"REPLACED" d <> None && find_index ~sub:"target" d = None);

  check "replace_all changes the document" (fun () ->
      let q = SearchQuery.create ~search:"gonefoo" ~replace:"GONE" () in
      dispatch_query q;
      set_cursor 0;
      ignore (replace_all view);
      let d = doc_string () in
      count_occurrences ~sub:"GONE" d = 3 && find_index ~sub:"gonefoo" d = None);

  check "highlight_selection_matches marks matches in the DOM" (fun () ->
      match find_all_indices ~sub:"dup" (doc_string ()) with
      | first :: _ :: _ ->
          set_range ~anchor:first ~head:(first + 3);
          El.find_first_by_selector ~root:(EditorView.dom view)
            (Jstr.v ".cm-selectionMatch")
          <> None
      | _ -> false);

  check "open_search_panel opens the panel" (fun () ->
      ignore (open_search_panel view);
      search_panel_open (EditorView.state view)
      && El.find_first_by_selector ~root:(EditorView.dom view)
           (Jstr.v ".cm-search")
         <> None);

  check "close_search_panel closes the panel" (fun () ->
      ignore (close_search_panel view);
      not (search_panel_open (EditorView.state view)));

  check "SearchCursor collects matches over a document directly" (fun () ->
      let text = Text.of_string "aaa bbb aaa ccc aaa" in
      let cur = SearchCursor.create text "aaa" in
      let matches = List.rev (SearchCursor.fold cur ~init:[] List.cons) in
      match matches with
      | [ m1; m2; m3 ] ->
          m1.from = 0 && m1.to_ = 3 && m2.from = 8 && m2.to_ = 11
          && m3.from = 16 && m3.to_ = 19
      | _ -> false);

  check "SearchCursor.iter visits every match" (fun () ->
      let text = Text.of_string "x y x y x" in
      let n = ref 0 in
      SearchCursor.iter (SearchCursor.create text "x") (fun _ -> incr n);
      !n = 3);

  check "RegExpCursor collects matches with capture groups" (fun () ->
      let text = Text.of_string "a1 b22 c333" in
      let cur = RegExpCursor.create text "[a-z](\\d+)" in
      let matches = List.rev (RegExpCursor.fold cur ~init:[] List.cons) in
      match matches with
      | [ m1; m2; m3 ] ->
          m1.captures.(1) = Some "1"
          && m2.captures.(1) = Some "22"
          && m3.captures.(1) = Some "333"
      | _ -> false);

  check "SearchQuery.get_cursor drives a cursor over the state" (fun () ->
      let q = SearchQuery.create ~search:"needle" () in
      let cur = SearchQuery.get_cursor q (`State (EditorView.state view)) in
      let n = SearchCursor.fold cur ~init:0 (fun _ acc -> acc + 1) in
      n = 3);

  report ()
