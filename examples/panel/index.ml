(* Panels: a StateField of bool tracks whether the panel is open, an
   effect flips it, and [Facet.from] hooks the field into [show_panel] so
   the panel appears and disappears with the field's value. A keymap
   binding runs the toggle. *)

open Brr
open Cm_state
open Cm_view

let panel_toggle : bool StateEffectType.t = StateEffectType.define Conv.bool

let panel_ctor (_view : editor_view) : Panel.t =
  Panel.create (El.div [ El.txt' "Hello! This is a panel" ])

let panel_field : bool StateField.t =
  StateField.define Conv.bool
    ~create:(fun _ -> false)
    ~update:(fun cur tr ->
      List.fold_left
        (fun cur eff ->
          match StateEffect.value eff panel_toggle with
          | Some b -> b
          | None -> cur)
        cur (Transaction.effects tr))
    ~provide:(fun field ->
      Facet.from
        ~get:(fun on -> if on then Some panel_ctor else None)
        show_panel field)

let toggle_panel view =
  let cur = EditorState.field (EditorView.state view) panel_field in
  EditorView.dispatch view
    (TransactionSpec.create
       ~effects:[ StateEffectType.of_ panel_toggle (not cur) ]
       ());
  true

let keymap_ext =
  Facet.of_ keymap [ KeyBinding.create ~key:"F1" ~run:toggle_panel () ]

let container = El.div []
let () = El.append_children (Document.body G.document) [ container ]

let config =
  EditorStateConfig.create ~doc:"Press F1 to toggle the panel."
    ~extensions:
      (Extension.of_list [ keymap_ext; StateField.extension panel_field ])
    ()

let state = EditorState.create ~config ()

let view =
  EditorView.create
    ~config:(EditorViewConfig.create ~state ~parent:container ())
    ()

(* -- self-check -------------------------------------------------------- *)

let details = ref []

let check name f =
  let ok = try f () with _ -> false in
  details := (name, ok) :: !details

let () =
  check "the panel field starts closed" (fun () ->
      not (EditorState.field (EditorView.state view) panel_field));

  check "F1 toggles the panel field on" (fun () ->
      ignore (toggle_panel view);
      EditorState.field (EditorView.state view) panel_field);

  check "the panel appears in the DOM once shown" (fun () ->
      El.find_by_tag_name ~root:(EditorView.dom view) (Jstr.v "div")
      |> List.exists (fun e ->
             Jstr.find_sub
               ~sub:(Jstr.v "Hello! This is a panel")
               (El.text_content e)
             <> None));

  let jv_of_pair (name, ok) =
    Jv.obj [| ("name", Jv.of_string name); ("ok", Jv.of_bool ok) |]
  in
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
