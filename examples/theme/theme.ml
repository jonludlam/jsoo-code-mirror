(* Themes: an editor's colours come from an extension, so a page can stack
   them. Here the One Dark theme from its own package, with a small theme
   of our own on top, built with EditorView.theme. *)

open Brr
open Code_mirror

let mine =
  View.EditorView.theme ~dark:true
    View.StyleSpec.
      [
        ("&", Rules [ ("maxWidth", Value "40em") ]);
        (".cm-content", Rules [ ("fontFamily", Value "monospace") ]);
      ]

let container = El.div []
let () = El.append_children (Document.body G.document) [ container ]

let config =
  State.EditorStateConfig.create ~doc:"One Dark, with a theme of our own."
    ~extensions:
      (State.Extension.of_list [ Theme_one_dark.one_dark; mine; basic_setup ])
    ()

let state = State.EditorState.create ~config ()

let view =
  View.EditorView.create
    ~config:(View.EditorViewConfig.create ~state ~parent:container ())
    ()

(* -- self-check -------------------------------------------------------- *)

let details = ref []

let check name f =
  let ok = try f () with _ -> false in
  details := (name, ok) :: !details

let style_text_contains substr =
  El.find_by_tag_name (Jstr.v "style")
  |> List.exists (fun s ->
         Jstr.find_sub ~sub:(Jstr.v substr) (El.text_content s) <> None)

let () =
  check "the dark_theme facet reflects One Dark" (fun () ->
      State.EditorState.facet
        (View.EditorView.state view)
        View.EditorView.dark_theme);

  check "our own theme's max-width rule is injected" (fun () ->
      style_text_contains "max-width");

  check "our own theme's monospace content font is injected" (fun () ->
      style_text_contains "monospace");

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
