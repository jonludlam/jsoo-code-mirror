(* https://codemirror.net/examples/translate/ *)

open Brr
open Cm_state
open Cm_view

(*!germanPhrases*)

let german_phrases =
  Jv.obj
    [|
      (* @codemirror/view *)
      ("Control character", Jv.of_string "Steuerzeichen");
      (* @codemirror/commands *)
      ("Selection deleted", Jv.of_string "Auswahl gelöscht");
      (* @codemirror/language *)
      ("Folded lines", Jv.of_string "Eingeklappte Zeilen");
      ("Unfolded lines", Jv.of_string "Ausgeklappte Zeilen");
      ("to", Jv.of_string "bis");
      ("folded code", Jv.of_string "eingeklappter Code");
      ("unfold", Jv.of_string "ausklappen");
      ("Fold line", Jv.of_string "Zeile einklappen");
      ("Unfold line", Jv.of_string "Zeile ausklappen");
      (* @codemirror/search *)
      ("Go to line", Jv.of_string "Springe zu Zeile");
      ("go", Jv.of_string "OK");
      ("Find", Jv.of_string "Suchen");
      ("Replace", Jv.of_string "Ersetzen");
      ("next", Jv.of_string "nächste");
      ("previous", Jv.of_string "vorherige");
      ("all", Jv.of_string "alle");
      ("match case", Jv.of_string "groß/klein beachten");
      ("by word", Jv.of_string "ganze Wörter");
      ("replace", Jv.of_string "ersetzen");
      ("replace all", Jv.of_string "alle ersetzen");
      ("close", Jv.of_string "schließen");
      ("current match", Jv.of_string "aktueller Treffer");
      ("replaced $ matches", Jv.of_string "$ Treffer ersetzt");
      ("replaced match on line $", Jv.of_string "Treffer on Zeile $ ersetzt");
      ("on line", Jv.of_string "auf Zeile");
      (* @codemirror/autocomplete *)
      ("Completions", Jv.of_string "Vervollständigungen");
      (* @codemirror/lint *)
      ("Diagnostics", Jv.of_string "Diagnosen");
      ("No diagnostics", Jv.of_string "Keine Diagnosen");
    |]

(*!create*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           "CodeMirror auf Deutsch übersetzt\n\n\
            Versuche zum Beispiel Strg-F für die Suchfunktion, oder bewege die\n\
            Mauszeiger über dieses Zeichen: \x11\n"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Facet.of_ EditorState.phrases german_phrases;
              ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor")))
         ())
    ()

let () = Jv.set Jv.global "view" (EditorView.to_jv view)
