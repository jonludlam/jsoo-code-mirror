(* The other code on https://codemirror.net/examples/config/, each run on
   a second editor. Upstream's first snippet uses lang-python. *)

open Brr
open Cm_state
open Cm_view

let language = Compartment.make ()
let tab_size = Compartment.make ()

let state =
  EditorState.create
    ~config:
      (EditorStateConfig.create ~doc:"def greet(name):\n\tprint(name)\n"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Compartment.of_ language
                  (Cm_language.LanguageSupport.extension
                     (Cm_lang_python.python ()));
                Compartment.of_ tab_size
                  (Facet.of_ EditorState.tab_size_facet 8);
              ])
         ())
    ()

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~state
         ~parent:
           (Option.get (Document.find_el_by_id G.document (Jstr.v "snippets")))
         ())
    ()

let set_tab_size view size =
  EditorView.dispatch view
    (TransactionSpec.create
       ~effects:
         [
           Compartment.reconfigure tab_size
             (Facet.of_ EditorState.tab_size_facet size);
         ]
       ())

let toggle_with key extension =
  let my_compartment = Compartment.make () in
  let toggle view =
    let on =
      match Compartment.get my_compartment (EditorView.state view) with
      | Some e ->
          Jv.strict_equal (Extension.to_jv e) (Extension.to_jv extension)
      | None -> false
    in
    EditorView.dispatch view
      (TransactionSpec.create
         ~effects:
           [
             Compartment.reconfigure my_compartment
               (if on then Extension.empty else extension);
           ]
         ());
    true
  in
  Extension.of_list
    [
      Compartment.of_ my_compartment Extension.empty;
      Facet.of_ keymap [ KeyBinding.create ~key ~run:toggle () ];
    ]

let yellow =
  toggle_with "Mod-o"
    (Facet.of_ EditorView.editor_attributes [ ("style", "background: yellow") ])

let deconfigure view =
  EditorView.dispatch view
    (TransactionSpec.create
       ~effects:
         [ StateEffectType.of_ StateEffectType.reconfigure Extension.empty ]
       ())

let inject_extension view extension =
  EditorView.dispatch view
    (TransactionSpec.create
       ~effects:[ StateEffectType.of_ StateEffectType.append_config extension ]
       ())

let () = inject_extension view yellow
