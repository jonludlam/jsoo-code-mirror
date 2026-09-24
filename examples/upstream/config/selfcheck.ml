open Cm_state
open Cm_view
open Example_check

let lang_name view =
  match EditorState.facet (EditorView.state view) Cm_language.language with
  | Some l -> Cm_language.Language.name l
  | None -> "none"

let () =
  keep [ Language.view; Snippets.view ];
  let view = Language.view in
  check "the editor starts as JavaScript" (fun () ->
      lang_name view = "javascript");
  check "typing a tag at the start switches it to HTML" (fun () ->
      EditorView.dispatch view
        (TransactionSpec.create ~changes:(ChangeSpec.insert ~at:0 "<div>") ());
      lang_name view = "html");
  check "and removing it switches back" (fun () ->
      EditorView.dispatch view
        (TransactionSpec.create ~changes:(ChangeSpec.delete ~from:0 ~to_:5) ());
      lang_name view = "javascript");
  let v = Snippets.view in
  check "the snippet editor is Python with a tab size of 8" (fun () ->
      lang_name v = "python" && EditorState.tab_size (EditorView.state v) = 8);
  check "set_tab_size reconfigures the tab size" (fun () ->
      Snippets.set_tab_size v 4;
      EditorState.tab_size (EditorView.state v) = 4);
  check "the injected Mod-o toggles a yellow background" (fun () ->
      let bg () =
        contains ~sub:"yellow"
          (Option.fold ~none:"" ~some:Jstr.to_string
             (Brr.El.at (Jstr.v "style") (EditorView.dom v)))
      in
      ignore (press_mod v "o");
      let on = bg () in
      ignore (press_mod v "o");
      on && not (bg ()));
  (* on a view of its own, so the page's editor keeps its configuration *)
  check "deconfigure leaves an editor with no language" (fun () ->
      let scratch =
        EditorView.create
          ~config:(EditorViewConfig.create ~state:Snippets.state ())
          ()
      in
      Snippets.deconfigure scratch;
      lang_name scratch = "none" && lang_name v = "python");
  report ()
