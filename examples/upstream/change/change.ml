(* https://codemirror.net/examples/change/

   Upstream's page shows four ways to change the document; each runs here
   on an editor, in order. *)

open Brr
open Cm_state
open Cm_view

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"\tconsole.log(\"hello\")\n\treturn tabs"
         ~extensions:Code_mirror.basic_setup ~parent:(Document.body G.document)
         ())
    ()

(* Insert text at the start of the document *)
let () =
  EditorView.dispatch view
    (TransactionSpec.create
       ~changes:(ChangeSpec.insert ~at:0 "#!/usr/bin/env node\n")
       ())

(* Replace every tab with two spaces, as one transaction *)
let () =
  let text = Text.to_string (EditorState.doc (EditorView.state view)) in
  let changes = ref [] in
  String.iteri
    (fun next c ->
      if c = '\t' then
        changes :=
          ChangeSpec.replace ~from:next ~to_:(next + 1) ~insert:"  " ()
          :: !changes)
    text;
  EditorView.dispatch view
    (TransactionSpec.create
       ~changes:(ChangeSpec.of_list (List.rev !changes))
       ())

(* Replace the selection *)
let () =
  EditorView.dispatch view
    (EditorState.replace_selection (EditorView.state view) "★")

(* Wrap every selection range in underscores. JavaScript's
   [changeByRange] returns a spec to dispatch; the binding returns its
   parts, which make the same spec. *)
let () =
  let changes, selection, effects =
    EditorState.change_by_range (EditorView.state view) (fun range ->
        {
          changes =
            Some
              (ChangeSpec.of_list
                 [
                   ChangeSpec.insert ~at:(SelectionRange.from range) "_";
                   ChangeSpec.insert ~at:(SelectionRange.to_ range) "_";
                 ]);
          range =
            EditorSelection.range
              ~anchor:(SelectionRange.from range)
              ~head:(SelectionRange.to_ range + 2)
              ();
          effects = [];
        })
  in
  EditorView.dispatch view
    (TransactionSpec.create
       ~changes:(ChangeSet.to_spec changes)
       ~selection:(TransactionSpec.Selection selection) ~effects ())
