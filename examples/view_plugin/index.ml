(* A ViewPlugin that highlights every occurrence of the word currently
   under the cursor, recomputed on each update. The plugin's value is a
   mutable record: CodeMirror's [PluginValue.update] returns nothing, so
   [update] mutates it in place, and [decorations] reads the current set
   back out for the [EditorView.decorations] facet. *)

open Brr
open Cm_state
open Cm_view

type plugin_state = { mutable deco : Decoration.t RangeSet.t }

let is_word_char c =
  (c >= 'a' && c <= 'z')
  || (c >= 'A' && c <= 'Z')
  || (c >= '0' && c <= '9')
  || c = '_'

(* Every whole-word occurrence of [word] in [doc]: a match only counts if
   the characters immediately before and after it (if any) are not
   themselves word characters. *)
let find_whole_word_occurrences ~word doc =
  let wlen = String.length word and len = String.length doc in
  let boundary i = i < 0 || i >= len || not (is_word_char doc.[i]) in
  let rec go i acc =
    if i + wlen > len then List.rev acc
    else if
      String.sub doc i wlen = word && boundary (i - 1) && boundary (i + wlen)
    then go (i + 1) ((i, i + wlen) :: acc)
    else go (i + 1) acc
  in
  go 0 []

let mark = Decoration.mark ~class_:"cm-word-occurrence" ()

let compute_decorations (view : EditorView.t) : Decoration.t RangeSet.t =
  let state = EditorView.state view in
  let cursor =
    SelectionRange.head (EditorSelection.main (EditorState.selection state))
  in
  match EditorState.word_at state cursor with
  | None -> Decoration.none
  | Some range -> (
      let word =
        EditorState.slice_doc
          ~from:(SelectionRange.from range)
          ~to_:(SelectionRange.to_ range) state
      in
      match
        find_whole_word_occurrences ~word
          (Text.to_string (EditorState.doc state))
      with
      | [] -> Decoration.none
      | matches ->
          Decoration.set
            (List.map
               (fun (from, to_) -> Decoration.range mark ~from ~to_)
               matches))

let word_highlighter : plugin_state ViewPlugin.t =
  ViewPlugin.define
    ~update:(fun s u ->
      if ViewUpdate.doc_changed u || ViewUpdate.selection_set u then
        s.deco <- compute_decorations (ViewUpdate.view u))
    ~decorations:(fun s -> s.deco)
    (fun view -> { deco = compute_decorations view })

let doc_text =
  "the cat sat on the mat\n\
   the cat and the cat watched a dog\n\
   the dog barked once"

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]

(* Visible even with no page stylesheet of our own, the way the mark
   decoration in test/view/view.ml relies on its own theme too. *)
let highlight_theme =
  EditorView.base_theme
    [
      ( ".cm-word-occurrence",
        StyleSpec.Rules [ ("backgroundColor", StyleSpec.Value "#ffe38f") ] );
    ]

let extensions =
  Extension.of_list
    [ ViewPlugin.extension word_highlighter; line_numbers (); highlight_theme ]

let editor_state_config = EditorStateConfig.create ~doc:doc_text ~extensions ()
let editor_state = EditorState.create ~config:editor_state_config ()

let view_config =
  EditorViewConfig.create ~state:editor_state ~parent:container ()

let view = EditorView.create ~config:view_config ()

(* -- self-check ------------------------------------------------------------ *)

open Example_check

let mark_count () =
  List.length
    (El.find_by_class ~root:(EditorView.dom view) (Jstr.v "cm-word-occurrence"))

let set_cursor pos =
  EditorView.dispatch view
    (TransactionSpec.create ~selection:(TransactionSpec.Cursor pos) ())

let () =
  keep [ view ];
  check "initial document renders" (fun () ->
      Jstr.find_sub ~sub:(Jstr.v "cat")
        (El.text_content (EditorView.content_dom view))
      <> None);

  check "cursor on \"cat\" highlights all 3 occurrences" (fun () ->
      set_cursor 4 (* the 'c' of "cat" on the first line *);
      mark_count () = 3);

  check "moving the cursor onto \"the\" highlights all 5 occurrences" (fun () ->
      set_cursor 0 (* the 't' of "the" on the first line *);
      mark_count () = 5);

  check "editing the document updates the highlight (recomputed on each update)"
    (fun () ->
      set_cursor 4 (* back onto a "cat" *);
      let len =
        String.length (Text.to_string (EditorState.doc (EditorView.state view)))
      in
      EditorView.dispatch view
        (TransactionSpec.create ~changes:(ChangeSpec.insert ~at:len " cat") ());
      mark_count () = 4);

  report ()
