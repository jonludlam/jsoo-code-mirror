(* https://codemirror.net/examples/basic/ *)

open Brr
open Cm_state
open Cm_view

let body = Document.body G.document

(* The editor with CodeMirror's basic setup. *)
let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"Start document" ~parent:body
         ~extensions:Code_mirror.basic_setup ())
    ()

(* The same setup, spelled out. *)
let manual_view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"Start document" ~parent:body
         ~extensions:
           (Extension.of_list
              [
                (* A line number gutter *)
                line_numbers ();
                (* A gutter with code folding markers *)
                Cm_language.fold_gutter ();
                (* Replace non-printable characters with placeholders *)
                highlight_special_chars ();
                (* The undo history *)
                Cm_commands.history ();
                (* Replace native cursor/selection with our own *)
                draw_selection ();
                (* Show a drop cursor when dragging over the editor *)
                drop_cursor ();
                (* Allow multiple cursors/selections *)
                Facet.of_ EditorState.allow_multiple_selections true;
                (* Re-indent lines when typing specific input *)
                Cm_language.indent_on_input ();
                (* Highlight syntax with a default style *)
                Cm_language.syntax_highlighting
                  Cm_language.default_highlight_style;
                (* Highlight matching brackets near cursor *)
                Cm_language.bracket_matching ();
                (* Automatically close brackets *)
                Cm_autocomplete.close_brackets ();
                (* Load the autocompletion system *)
                Cm_autocomplete.autocompletion ();
                (* Allow alt-drag to select rectangular regions *)
                rectangular_selection ();
                (* Change the cursor to a crosshair when holding alt *)
                crosshair_cursor ();
                (* Style the current line specially *)
                highlight_active_line ();
                (* Style the gutter for current line specially *)
                highlight_active_line_gutter ();
                (* Highlight text that matches the selected text *)
                Cm_search.highlight_selection_matches ();
                Facet.of_ keymap
                  (List.concat
                     [
                       (* Closed-brackets aware backspace *)
                       Cm_autocomplete.close_brackets_keymap;
                       (* A large set of basic bindings *)
                       Cm_commands.default_keymap;
                       (* Search-related keys *)
                       Cm_search.search_keymap;
                       (* Redo/undo keys *)
                       Cm_commands.history_keymap;
                       (* Code folding bindings *)
                       Cm_language.fold_keymap;
                       (* Autocompletion keys *)
                       Cm_autocomplete.completion_keymap;
                       (* Keys related to the linter system *)
                       Cm_lint.lint_keymap;
                     ]);
              ])
         ())
    ()

(* The basic setup, with a language: TypeScript. *)
let typescript_view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"Start document" ~parent:body
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Cm_language.LanguageSupport.extension
                  (Cm_lang_javascript.javascript ~typescript:true ());
              ])
         ())
    ()
