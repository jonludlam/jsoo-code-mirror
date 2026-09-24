(* https://codemirror.net/examples/panel/ *)

open Brr
open Cm_state
open Cm_view

(*!helpState*)

let toggle_help = StateEffectType.define Conv.bool

(*!createHelpPanel*)

let create_help_panel (_view : EditorView.t) =
  let dom =
    El.div
      ~at:At.[ class' (Jstr.v "cm-help-panel") ]
      [ El.txt' "F1: Toggle the help panel" ]
  in
  Panel.create ~top:true dom

let help_panel_state =
  StateField.define Conv.bool
    ~create:(fun _ -> false)
    ~update:(fun value tr ->
      List.fold_left
        (fun value e ->
          match StateEffect.value e toggle_help with
          | Some v -> v
          | None -> value)
        value (Transaction.effects tr))
    ~provide:(fun f ->
      Facet.from show_panel f ~get:(fun on ->
          if on then Some create_help_panel else None))

(*!helpKeymap*)

let help_keymap =
  [
    KeyBinding.create ~key:"F1"
      ~run:(fun view ->
        EditorView.dispatch view
          (TransactionSpec.create
             ~effects:
               [
                 StateEffectType.of_ toggle_help
                   (not
                      (EditorState.field (EditorView.state view)
                         help_panel_state));
               ]
             ());
        true)
      ();
  ]

(*!helpPanel*)

let help_theme =
  EditorView.base_theme
    StyleSpec.
      [
        ( ".cm-help-panel",
          Rules
            [
              ("padding", Value "5px 10px");
              ("backgroundColor", Value "#fffa8f");
              ("fontFamily", Value "monospace");
            ] );
      ]

let help_panel () =
  Extension.of_list
    [
      StateField.extension help_panel_state;
      Facet.of_ keymap help_keymap;
      help_theme;
    ]

(*!create*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:"In this editor, F1 is bound to a panel-toggling\ncommand.\n"
         ~extensions:
           (Extension.of_list [ help_panel (); Code_mirror.basic_setup ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()

let () = Jv.set Jv.global "view" (EditorView.to_jv view)
