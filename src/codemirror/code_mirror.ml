(* The codemirror package: basicSetup and minimalSetup. They are only two
   lists of extensions from the other packages, so rather than bundle the
   package they are transcribed here from its dist/index.js (codemirror
   6.0.1), in the same order. *)

open struct
  let get package name = Jv.get (Jv.get Jv.global ("__CM__" ^ package)) name
  let call package name = Jv.apply (get package name) [||]

  let syntax_highlighting () =
    Jv.apply
      (get "language" "syntaxHighlighting")
      [|
        get "language" "defaultHighlightStyle";
        Jv.obj [| ("fallback", Jv.true') |];
      |]

  let keymap keymaps =
    let bindings =
      List.concat_map
        (fun (package, name) -> Jv.to_jv_list (get package name))
        keymaps
    in
    Jv.call (get "view" "keymap") "of" [| Jv.of_jv_list bindings |]
end

let basic_setup : Cm_state.Extension.t =
  Cm_state.Extension.of_jv
    (Jv.of_jv_list
       [
         call "view" "lineNumbers";
         call "view" "highlightActiveLineGutter";
         call "view" "highlightSpecialChars";
         call "commands" "history";
         call "language" "foldGutter";
         call "view" "drawSelection";
         call "view" "dropCursor";
         Jv.call
           (Jv.get (get "state" "EditorState") "allowMultipleSelections")
           "of" [| Jv.true' |];
         call "language" "indentOnInput";
         syntax_highlighting ();
         call "language" "bracketMatching";
         call "autocomplete" "closeBrackets";
         call "autocomplete" "autocompletion";
         call "view" "rectangularSelection";
         call "view" "crosshairCursor";
         call "view" "highlightActiveLine";
         call "search" "highlightSelectionMatches";
         keymap
           [
             ("autocomplete", "closeBracketsKeymap");
             ("commands", "defaultKeymap");
             ("search", "searchKeymap");
             ("commands", "historyKeymap");
             ("language", "foldKeymap");
             ("autocomplete", "completionKeymap");
             ("lint", "lintKeymap");
           ];
       ])

let minimal_setup : Cm_state.Extension.t =
  Cm_state.Extension.of_jv
    (Jv.of_jv_list
       [
         call "view" "highlightSpecialChars";
         call "commands" "history";
         call "view" "drawSelection";
         syntax_highlighting ();
         keymap [ ("commands", "defaultKeymap"); ("commands", "historyKeymap") ];
       ])
