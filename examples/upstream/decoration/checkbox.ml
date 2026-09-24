(* https://codemirror.net/examples/decoration/, its second editor *)

open Brr
open Cm_state
open Cm_view

(*!CheckboxWidget*)

(* A class whose instances carry [checked]. *)
let checkbox_widget =
  WidgetType.define
    ~eq:(fun checked other -> other = checked)
    ~to_dom:(fun checked _ ->
      let box = El.input ~at:[ At.type' (Jstr.v "checkbox") ] () in
      Jv.Bool.set (El.to_jv box) "checked" checked;
      El.span
        ~at:
          At.
            [
              v (Jstr.v "aria-hidden") (Jstr.v "true");
              class' (Jstr.v "cm-boolean-toggle");
            ]
        [ box ])
    ~ignore_event:(fun _ _ -> false)
    ()

(*!checkboxes*)

let checkboxes view =
  let widgets = ref [] in
  let state = EditorView.state view in
  List.iter
    (fun (from, to_) ->
      Cm_language.Tree.iterate ~from ~to_
        (Cm_language.syntax_tree state)
        ~enter:(fun node ->
          (if Cm_language.SyntaxNode.name node = "BooleanLiteral" then
             let is_true =
               Text.slice_string
                 ~from:(Cm_language.SyntaxNode.from node)
                 ~to_:(Cm_language.SyntaxNode.to_ node)
                 (EditorState.doc state)
               = "true"
             in
             let deco = Decoration.widget ~side:1 (checkbox_widget is_true) in
             widgets :=
               Decoration.range deco ~from:(Cm_language.SyntaxNode.to_ node)
               :: !widgets);
          true)
        ())
    (EditorView.visible_ranges view);
  Decoration.set (List.rev !widgets)

(*!toggleBoolean*)

let toggle_boolean view pos =
  let before =
    Text.slice_string
      ~from:(max 0 (pos - 5))
      ~to_:pos
      (EditorState.doc (EditorView.state view))
  in
  let change =
    if before = "false" then
      Some (ChangeSpec.replace ~from:(pos - 5) ~to_:pos ~insert:"true" ())
    else if String.ends_with ~suffix:"true" before then
      Some (ChangeSpec.replace ~from:(pos - 4) ~to_:pos ~insert:"false" ())
    else None
  in
  match change with
  | None -> false
  | Some change ->
      EditorView.dispatch view (TransactionSpec.create ~changes:change ());
      true

(*!checkboxPlugin*)

type checkbox_plugin = { mutable decorations : Decoration.t RangeSet.t }

let checkbox_plugin =
  ViewPlugin.define
    ~update:(fun this update ->
      if
        ViewUpdate.doc_changed update
        || ViewUpdate.viewport_changed update
        || not
             (Jv.strict_equal
                (Cm_language.Tree.to_jv
                   (Cm_language.syntax_tree (ViewUpdate.start_state update)))
                (Cm_language.Tree.to_jv
                   (Cm_language.syntax_tree (ViewUpdate.state update))))
      then this.decorations <- checkboxes (ViewUpdate.view update))
    ~decorations:(fun v -> v.decorations)
    ~event_handlers:
      [
        ( "mousedown",
          fun _ e view ->
            let target = Jv.get (Ev.to_jv e) "target" in
            let el = El.of_jv target in
            if
              Jv.to_string (Jv.get target "nodeName") = "INPUT"
              && El.class'
                   (Jstr.v "cm-boolean-toggle")
                   (El.of_jv (Jv.get target "parentElement"))
            then toggle_boolean view (EditorView.pos_at_dom view el)
            else false );
      ]
    (fun view -> { decorations = checkboxes view })

(*!create*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           "let value = true\nif (!value == false)\n  console.log(\"good\")\n"
         ~extensions:
           (Extension.of_list
              [
                ViewPlugin.extension checkbox_plugin;
                Code_mirror.basic_setup;
                Cm_language.LanguageSupport.extension
                  (Cm_lang_javascript.javascript ());
              ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor-checkbox")))
         ())
    ()
