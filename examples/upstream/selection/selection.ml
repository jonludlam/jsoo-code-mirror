(* https://codemirror.net/examples/selection/

   Upstream's page shows three dispatches; each runs here on an editor,
   in order. *)

open Brr
open Cm_state
open Cm_view

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"Hello, this is a demo document."
         ~extensions:Code_mirror.basic_setup ~parent:(Document.body G.document)
         ())
    ()

(* Put the cursor at the start. *)
let () =
  EditorView.dispatch view
    (TransactionSpec.create ~selection:(TransactionSpec.Cursor 0) ())

(* Two ranges and a cursor, the second range being the main one. *)
let () =
  EditorView.dispatch view
    (TransactionSpec.create
       ~selection:
         (TransactionSpec.Selection
            (EditorSelection.create ~main_index:1
               [
                 EditorSelection.range ~anchor:4 ~head:5 ();
                 EditorSelection.range ~anchor:6 ~head:7 ();
                 EditorSelection.cursor 8;
               ]))
       ())

(* Insert an asterisk and put the cursor after it. *)
let () =
  EditorView.dispatch view
    (TransactionSpec.create
       ~changes:(ChangeSpec.insert ~at:10 "*")
       ~selection:(TransactionSpec.Cursor 11) ())
