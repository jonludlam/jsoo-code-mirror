(* Browser exerciser for code-mirror.view: creates a real editor, dispatches
   transactions, and checks that mark/widget decorations, a counting
   ViewPlugin, line_numbers, a panel, a keymap-bound command, theme/
   base_theme and update_listener all work. Not a Playwright runner: this
   page just runs itself and reports through [window.viewTestResults], the
   same shape test/link uses. *)

open Brr
open Cm_state
open Cm_view

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
  Jv.set Jv.global "viewTestResults" result

(* -- fixtures: a mark decoration + a widget decoration, driven by a
   custom effect and carried in a StateField --------------------------- *)

let mark_effect_conv : (int * int) Conv.t =
  {
    Conv.to_jv = (fun (from, to_) -> Jv.of_list Jv.of_int [ from; to_ ]);
    of_jv =
      (fun jv ->
        match Jv.to_list Jv.to_int jv with
        | [ from; to_ ] -> (from, to_)
        | _ -> Conv.invalid "mark_effect" jv);
  }

let mark_effect : (int * int) StateEffectType.t =
  StateEffectType.define mark_effect_conv

let mark_deco = Decoration.mark ~class_:"cm-test-mark" ()

let widget_deco =
  Decoration.widget ~block:true
    (WidgetType.make
       ~to_dom:(fun _view ->
         El.div ~at:At.[ class' (Jstr.v "cm-test-widget") ] [ El.txt' "note" ])
       ())

let deco_field : Decoration.t RangeSet.t StateField.t =
  StateField.define
    (RangeSet.conv Decoration.conv)
    ~create:(fun _ ->
      RangeSet.of_ Decoration.conv
        [ Range.make Decoration.conv ~from:0 ~to_:0 widget_deco ])
    ~update:(fun set tr ->
      let set = RangeSet.map set (ChangeSet.desc (Transaction.changes tr)) in
      List.fold_left
        (fun set eff ->
          match StateEffect.value eff mark_effect with
          | None -> set
          | Some (from, to_) ->
              RangeSet.update
                ~add:[ Range.make Decoration.conv ~from ~to_ mark_deco ]
                set)
        set (Transaction.effects tr))
    ~provide:(fun field -> Facet.from EditorView.decorations field)

(* -- fixtures: a ViewPlugin counting how many times it is updated --- *)

let count_plugin : int ref ViewPlugin.t =
  ViewPlugin.define ~update:(fun r _u -> incr r) (fun _view -> ref 0)

(* -- fixtures: a panel toggled by an effect through show_panel ------ *)

let panel_toggle : bool StateEffectType.t = StateEffectType.define Conv.bool

let panel_ctor (_view : editor_view) : Panel.t =
  let dom =
    El.div ~at:At.[ class' (Jstr.v "cm-test-panel") ] [ El.txt' "panel" ]
  in
  Panel.create dom

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

(* -- fixtures: a keymap binding running a command ------------------- *)

let command_ran = ref false

let my_command (_view : editor_view) : bool =
  command_ran := true;
  true

let key_binding = KeyBinding.create ~key:"F9" ~run:my_command ()
let keymap_ext = Facet.of_ keymap [ key_binding ]

(* -- fixtures: theme / base_theme and an update_listener ------------ *)

let theme_ext =
  EditorView.theme
    [
      ( ".cm-test-theme-marker",
        StyleSpec.Rules [ ("color", StyleSpec.Value "rgb(1, 2, 3)") ] );
    ]

let base_theme_ext =
  EditorView.base_theme
    [
      ( ".cm-test-base-marker",
        StyleSpec.Rules [ ("color", StyleSpec.Value "rgb(4, 5, 6)") ] );
    ]

let listener_count = ref 0

let listener_ext =
  Facet.of_ EditorView.update_listener (fun _u -> incr listener_count)

(* -- assemble the editor --------------------------------------------- *)

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]

let extensions =
  Extension.of_list
    [
      StateField.extension deco_field;
      ViewPlugin.extension count_plugin;
      line_numbers ~format_number:(fun n _state -> "L" ^ string_of_int n) ();
      StateField.extension panel_field;
      panels ();
      keymap_ext;
      theme_ext;
      base_theme_ext;
      listener_ext;
    ]

let editor_state_config =
  EditorStateConfig.create ~doc:"hello\nworld" ~extensions ()

let editor_state = EditorState.create ~config:editor_state_config ()

let view_config =
  EditorViewConfig.create ~state:editor_state ~parent:container ()

let view = EditorView.create ~config:view_config ()

(* -- checks ----------------------------------------------------------- *)

let content_text () = El.text_content (EditorView.content_dom view)
let contains ~sub s = Jstr.find_sub ~sub:(Jstr.v sub) (Jstr.v s) <> None
let jcontains ~sub s = Jstr.find_sub ~sub:(Jstr.v sub) s <> None

let style_text_contains substr =
  El.find_by_tag_name (Jstr.v "style")
  |> List.exists (fun s -> jcontains ~sub:substr (El.text_content s))

let () =
  check "initial document renders" (fun () ->
      let t = Jstr.to_string (content_text ()) in
      contains ~sub:"hello" t && contains ~sub:"world" t);

  check "widget decoration renders" (fun () ->
      El.find_first_by_selector ~root:(EditorView.dom view)
        (Jstr.v ".cm-test-widget")
      <> None);

  check "dispatch a transaction updates state and DOM" (fun () ->
      let changes = ChangeSpec.insert ~at:5 "!" in
      EditorView.dispatch view (TransactionSpec.create ~changes ());
      let doc = Text.to_string (EditorState.doc (EditorView.state view)) in
      contains ~sub:"hello!" doc && jcontains ~sub:"hello!" (content_text ()));

  check "mark decoration renders after an effect" (fun () ->
      let effects = [ StateEffectType.of_ mark_effect (0, 5) ] in
      EditorView.dispatch view (TransactionSpec.create ~effects ());
      El.find_first_by_selector ~root:(EditorView.dom view)
        (Jstr.v ".cm-test-mark")
      <> None);

  check "view plugin counted updates" (fun () ->
      match EditorView.plugin view count_plugin with
      | Some r -> !r > 0
      | None -> false);

  check "line_numbers format_number renders" (fun () ->
      El.find_by_class ~root:(EditorView.dom view) (Jstr.v "cm-gutterElement")
      |> List.exists (fun e -> Jstr.equal (El.text_content e) (Jstr.v "L1")));

  (* [get_panel]'s second argument is compared by JavaScript reference
     equality against whatever constructor CodeMirror currently has for
     the active panel. Since [(editor_view -> Panel.t) -> Jv.t] conversion
     allocates a fresh JavaScript closure on every call (there is no way
     to keep a stable handle to one through this typed signature), a
     constructor built at the call site can never `==` the one the
     [show_panel] facet computed internally; this call to [get_panel] is
     exercised for its own sake (and to confirm it does not raise) but
     its [None] result is expected, not a failure. See DESIGN.md's
     friction notes. *)
  check "panel toggled through show_panel appears" (fun () ->
      let effects = [ StateEffectType.of_ panel_toggle true ] in
      EditorView.dispatch view (TransactionSpec.create ~effects ());
      ignore (get_panel view panel_ctor);
      El.find_first_by_selector ~root:(EditorView.dom view)
        (Jstr.v ".cm-test-panel")
      <> None);

  check "keymap binding runs its command" (fun () ->
      let synthetic =
        Jv.new'
          (Jv.get Jv.global "KeyboardEvent")
          [| Jv.of_string "keydown"; Jv.obj [| ("key", Jv.of_string "F9") |] |]
      in
      let handled = run_scope_handlers view (Brr.Ev.of_jv synthetic) "editor" in
      handled && !command_ran);

  check "theme extension injects a style rule" (fun () ->
      style_text_contains "cm-test-theme-marker");
  check "base_theme extension injects a style rule" (fun () ->
      style_text_contains "cm-test-base-marker");
  check "update_listener fired" (fun () -> !listener_count > 0);

  report ()
