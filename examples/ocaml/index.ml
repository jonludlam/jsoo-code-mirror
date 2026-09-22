(* The flagship example: an OCaml editor. This is the whole of what
   embedding CodeMirror for a real language takes - a CodeMirror 5
   stream-parser mode turned into a Language, the One Dark theme, and
   [basic_setup] (line numbers, history, search, autocompletion, the
   default key bindings), stacked as extensions in a parent element. *)

open Code_mirror
open Brr

let ocaml_language =
  Language.StreamLanguage.to_language
    (Language.StreamLanguage.define Legacy_modes.ocaml)

let doc =
  "(* Fibonacci, the slow way. *)\n\
   let rec fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)\n"

let extensions =
  State.Extension.of_list
    [
      basic_setup;
      Language.Language.extension ocaml_language;
      Theme_one_dark.one_dark;
    ]

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]

let state =
  State.EditorState.create
    ~config:(State.EditorStateConfig.create ~doc ~extensions ())
    ()

let view =
  View.EditorView.create
    ~config:(View.EditorViewConfig.create ~state ~parent:container ())
    ()

(* -- self-check ---------------------------------------------------- *)

let details = ref []
let check name f = details := (name, try f () with _ -> false) :: !details
let contains ~sub s = Jstr.find_sub ~sub:(Jstr.v sub) (Jstr.v s) <> None

let style_text_contains sub =
  El.find_by_tag_name (Jstr.v "style")
  |> List.exists (fun s -> contains ~sub (Jstr.to_string (El.text_content s)))

let () =
  check "renders the OCaml source" (fun () ->
      let t =
        Jstr.to_string (El.text_content (View.EditorView.content_dom view))
      in
      contains ~sub:"let rec fib" t && contains ~sub:"Fibonacci" t);

  check "keywords are colored with the One Dark palette" (fun () ->
      style_text_contains Theme_one_dark.Color.violet);

  check "basic_setup adds a line-number gutter" (fun () ->
      El.find_first_by_selector ~root:(View.EditorView.dom view)
        (Jstr.v ".cm-lineNumbers")
      <> None);

  let details = List.rev !details in
  let total = List.length details in
  let passed = List.length (List.filter (fun (_, ok) -> ok) details) in
  let jv_of_pair (name, ok) =
    Jv.obj [| ("name", Jv.of_string name); ("ok", Jv.of_bool ok) |]
  in
  Jv.set Jv.global "exampleResults"
    (Jv.obj
       [|
         ("total", Jv.of_int total);
         ("passed", Jv.of_int passed);
         ("failed", Jv.of_int (total - passed));
         ("details", Jv.of_list jv_of_pair details);
         ("done", Jv.true');
       |])
