open Cm_state
open Cm_view
open Example_check

let number s = int_of_string (List.nth (String.split_on_char ' ' s) 1)

let () =
  let view = Zebra.view in
  check "every second line is striped, and only those" (fun () ->
      let s = texts (by_class view "cm-zebraStripe") in
      s <> [] && List.for_all (fun l -> number l mod 2 = 0) s);
  check "the step without configuration is 2" (fun () ->
      EditorState.facet (EditorView.state view) Zebra.step_size = 2);
  check "several steps combine to the smallest" (fun () ->
      let state =
        EditorState.create
          ~config:
            (EditorStateConfig.create
               ~extensions:
                 (Extension.of_list
                    [
                      Zebra.zebra_stripes ~step:5 ();
                      Zebra.zebra_stripes ~step:3 ();
                    ])
               ())
          ()
      in
      EditorState.facet state Zebra.step_size = 3);
  report ()
