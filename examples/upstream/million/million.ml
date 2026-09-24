(* https://codemirror.net/examples/million/ *)

open Brr
open Cm_state
open Cm_view

let lines = ref [ "<!doctype html>"; "<meta charset=\"utf8\">"; "<body>" ]

let repeated =
  [|
    "  <p>These lines are repeated many times to save memory on";
    "  string data.</p>";
    "  <hr>";
    "  <img src=\"../../style/logo.svg\">";
    "";
  |]

let () =
  let n = ref (List.length !lines)
  and rev = ref (List.rev !lines)
  and i = ref 0 in
  while !n < 2_000_000 do
    rev := repeated.(!i mod Array.length repeated) :: !rev;
    incr n;
    incr i
  done;
  lines := List.rev ("" :: "</body>" :: !rev)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~state:
           (EditorState.create
              ~config:
                (EditorStateConfig.create ~text:(Text.of_lines !lines)
                   ~extensions:
                     (Extension.of_list
                        [
                          Facet.of_ keymap
                            (Cm_commands.default_keymap
                           @ Cm_commands.history_keymap);
                          Cm_commands.history ();
                          draw_selection ();
                          Cm_language.syntax_highlighting
                            Cm_language.default_highlight_style;
                          line_numbers ();
                          Cm_language.LanguageSupport.extension
                            (Cm_lang_html.html ());
                        ])
                   ())
              ())
         ~parent:
           (Option.get (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()

let () = Jv.set Jv.global "view" (EditorView.to_jv view)
