(* Every bundle loads, in dependency order, and the page has one copy of
   each package. The state below takes extensions from all nine bundles;
   if any bundle carried its own copy of @codemirror/state, CodeMirror
   would not recognise them and EditorState.create would throw. Runs
   under node, so there is no view. *)

open Code_mirror

let globals =
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
  ]

let () =
  match List.filter (fun g -> Jv.is_undefined (Jv.get Jv.global g)) globals with
  | [] -> ()
  | missing -> failwith ("not loaded: " ^ String.concat ", " missing)

let ocaml_mode =
  let mllike = Jv.get (Jv.get Jv.global "__CM__legacy_modes") "mllike" in
  Language.Stream.Language.(define (of_jv (Jv.get mllike "oCaml")))

let () =
  let extensions =
    State.Extension.of_list [ basic_setup; Theme_one_dark.one_dark; ocaml_mode ]
  in
  let config = State.EditorStateConfig.create ~doc:"linked" ~extensions () in
  let state = State.EditorState.create ~config () in
  let doc = State.Text.to_string (State.EditorState.doc state) in
  if doc <> "linked" then failwith ("unexpected document: " ^ doc)
