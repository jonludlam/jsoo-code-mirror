(* https://codemirror.net/examples/split/ *)

open Brr
open Cm_state
open Cm_view

(*!startState*)

let start_state =
  EditorState.create
    ~config:
      (EditorStateConfig.create ~doc:"The document\nis\nshared"
         ~extensions:
           (Extension.of_list
              [
                Cm_commands.history ();
                draw_selection ();
                line_numbers ();
                Facet.of_ keymap
                  (Cm_commands.default_keymap @ Cm_commands.history_keymap);
              ])
         ())
    ()

(*!otherState*)

(* The two views refer to each other; they are filled in by [setup]. *)
let main_view = ref None
let other_view = ref None
let main () = Option.get !main_view

let other_state =
  EditorState.create
    ~config:
      (EditorStateConfig.create
         ~text:(EditorState.doc start_state)
         ~extensions:
           (Extension.of_list
              [
                draw_selection ();
                line_numbers ();
                Facet.of_ keymap
                  (Cm_commands.default_keymap
                  @ [
                      KeyBinding.create ~key:"Mod-z"
                        ~run:(fun _ -> Cm_commands.undo (main ()))
                        ();
                      KeyBinding.create ~key:"Mod-y" ~mac:"Mod-Shift-z"
                        ~run:(fun _ -> Cm_commands.redo (main ()))
                        ();
                    ]);
              ])
         ())
    ()

(*!syncDispatch*)

let sync_annotation : bool AnnotationType.t = AnnotationType.define Conv.bool

let sync_dispatch tr view other =
  EditorView.update view [ tr ];
  if
    (not (ChangeDesc.empty (ChangeSet.desc (Transaction.changes tr))))
    && Transaction.annotation tr sync_annotation = None
  then
    let annotations =
      AnnotationType.of_ sync_annotation true
      ::
      (match Transaction.annotation tr Transaction.user_event with
      | Some user_event ->
          [ AnnotationType.of_ Transaction.user_event user_event ]
      | None -> [])
    in
    EditorView.dispatch other
      (TransactionSpec.create
         ~changes:(ChangeSet.to_spec (Transaction.changes tr))
         ~annotations ())

(*!setup*)

let el id =
  Option.value ~default:(Document.body G.document)
    (Document.find_el_by_id G.document (Jstr.v id))

let () =
  main_view :=
    Some
      (EditorView.create
         ~config:
           (EditorViewConfig.create ~state:start_state ~parent:(el "editor1")
              ~dispatch_transactions:(fun trs view ->
                List.iter
                  (fun tr -> sync_dispatch tr view (Option.get !other_view))
                  trs)
              ())
         ());
  other_view :=
    Some
      (EditorView.create
         ~config:
           (EditorViewConfig.create ~state:other_state ~parent:(el "editor2")
              ~dispatch_transactions:(fun trs view ->
                List.iter (fun tr -> sync_dispatch tr view (main ())) trs)
              ())
         ())
