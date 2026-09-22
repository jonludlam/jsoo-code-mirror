open Brr

let () =
  let config = Cm_state.EditorStateConfig.create ~doc:"linked" () in
  let state = Cm_state.EditorState.create ~config () in
  let view_config =
    Cm_view.EditorViewConfig.create ~state ~parent:(Document.body G.document) ()
  in
  let view = Cm_view.EditorView.create ~config:view_config () in
  let s = Cm_view.EditorView.state view in
  let same_state_class =
    Jv.instanceof
      (Cm_state.EditorState.to_jv s)
      ~cons:(Jv.get (Jv.get Jv.global "__CM__state") "EditorState")
  in
  let globals =
    List.filter
      (fun g -> not (Jv.is_undefined (Jv.get Jv.global g)))
      [
        "__CM__state";
        "__CM__view";
        "__CM__language";
        "__CM__commands";
        "__CM__autocomplete";
        "__CM__lint";
        "__CM__search";
        "__CM__legacy_modes";
        "__CM__theme_one_dark";
        "__CM__codemirror";
      ]
  in
  let basic =
    not (Jv.is_undefined (Cm_state.Extension.to_jv Code_mirror.basic_setup))
  in
  Jv.set Jv.global "linkResult"
    (Jv.obj
       [|
         ( "doc",
           Jv.of_string (Cm_state.Text.to_string (Cm_state.EditorState.doc s))
         );
         ("sameStateClass", Jv.of_bool same_state_class);
         ("globals", Jv.of_list Jv.of_string globals);
         ("basicSetup", Jv.of_bool basic);
       |])
