open Cm_state
open Cm_view

let pkg = lazy (Jv.get Jv.global "__CM__commands")

(* A raw exported Command/StateCommand value, called against an editor_view
   the way CodeMirror itself calls it (both accept a view as their target);
   see src/search/cm_search.ml, which established this first. *)
let command_of_jv (raw : Jv.t) : command =
 fun (view : editor_view) ->
  Jv.apply raw [| EditorView.to_jv view |] |> Jv.to_bool

let cmd name : command = command_of_jv (Jv.get (Lazy.force pkg) name)

let keymap_of name : KeyBinding.t list =
  Jv.to_list KeyBinding.of_jv (Jv.get (Lazy.force pkg) name)

(* -- Cursor motion ---------------------------------------------------- *)

let cursor_char_left = cmd "cursorCharLeft"
let cursor_char_right = cmd "cursorCharRight"
let cursor_char_forward = cmd "cursorCharForward"
let cursor_char_backward = cmd "cursorCharBackward"
let cursor_char_forward_logical = cmd "cursorCharForwardLogical"
let cursor_char_backward_logical = cmd "cursorCharBackwardLogical"
let cursor_group_left = cmd "cursorGroupLeft"
let cursor_group_right = cmd "cursorGroupRight"
let cursor_group_forward = cmd "cursorGroupForward"
let cursor_group_backward = cmd "cursorGroupBackward"
let cursor_group_forward_win = cmd "cursorGroupForwardWin"
let cursor_subword_forward = cmd "cursorSubwordForward"
let cursor_subword_backward = cmd "cursorSubwordBackward"
let cursor_syntax_left = cmd "cursorSyntaxLeft"
let cursor_syntax_right = cmd "cursorSyntaxRight"
let cursor_line_up = cmd "cursorLineUp"
let cursor_line_down = cmd "cursorLineDown"
let cursor_page_up = cmd "cursorPageUp"
let cursor_page_down = cmd "cursorPageDown"
let cursor_line_boundary_forward = cmd "cursorLineBoundaryForward"
let cursor_line_boundary_backward = cmd "cursorLineBoundaryBackward"
let cursor_line_boundary_left = cmd "cursorLineBoundaryLeft"
let cursor_line_boundary_right = cmd "cursorLineBoundaryRight"
let cursor_line_start = cmd "cursorLineStart"
let cursor_line_end = cmd "cursorLineEnd"
let cursor_doc_start = cmd "cursorDocStart"
let cursor_doc_end = cmd "cursorDocEnd"
let cursor_matching_bracket = cmd "cursorMatchingBracket"

(* -- Selection ---------------------------------------------------------- *)

let select_matching_bracket = cmd "selectMatchingBracket"
let select_char_left = cmd "selectCharLeft"
let select_char_right = cmd "selectCharRight"
let select_char_forward = cmd "selectCharForward"
let select_char_backward = cmd "selectCharBackward"
let select_char_forward_logical = cmd "selectCharForwardLogical"
let select_char_backward_logical = cmd "selectCharBackwardLogical"
let select_group_left = cmd "selectGroupLeft"
let select_group_right = cmd "selectGroupRight"
let select_group_forward = cmd "selectGroupForward"
let select_group_backward = cmd "selectGroupBackward"
let select_group_forward_win = cmd "selectGroupForwardWin"
let select_subword_forward = cmd "selectSubwordForward"
let select_subword_backward = cmd "selectSubwordBackward"
let select_syntax_left = cmd "selectSyntaxLeft"
let select_syntax_right = cmd "selectSyntaxRight"
let select_line_up = cmd "selectLineUp"
let select_line_down = cmd "selectLineDown"
let select_page_up = cmd "selectPageUp"
let select_page_down = cmd "selectPageDown"
let select_line_boundary_forward = cmd "selectLineBoundaryForward"
let select_line_boundary_backward = cmd "selectLineBoundaryBackward"
let select_line_boundary_left = cmd "selectLineBoundaryLeft"
let select_line_boundary_right = cmd "selectLineBoundaryRight"
let select_line_start = cmd "selectLineStart"
let select_line_end = cmd "selectLineEnd"
let select_doc_start = cmd "selectDocStart"
let select_doc_end = cmd "selectDocEnd"
let select_all = cmd "selectAll"
let select_line = cmd "selectLine"
let select_parent_syntax = cmd "selectParentSyntax"
let simplify_selection = cmd "simplifySelection"

(* -- Deletion ------------------------------------------------------------ *)

let delete_char_backward = cmd "deleteCharBackward"
let delete_char_backward_strict = cmd "deleteCharBackwardStrict"
let delete_char_forward = cmd "deleteCharForward"
let delete_group_backward = cmd "deleteGroupBackward"
let delete_group_forward = cmd "deleteGroupForward"
let delete_to_line_end = cmd "deleteToLineEnd"
let delete_to_line_start = cmd "deleteToLineStart"
let delete_line_boundary_backward = cmd "deleteLineBoundaryBackward"
let delete_line_boundary_forward = cmd "deleteLineBoundaryForward"
let delete_trailing_whitespace = cmd "deleteTrailingWhitespace"
let delete_line = cmd "deleteLine"

(* -- Line manipulation ---------------------------------------------------- *)

let split_line = cmd "splitLine"
let transpose_chars = cmd "transposeChars"
let move_line_up = cmd "moveLineUp"
let move_line_down = cmd "moveLineDown"
let copy_line_up = cmd "copyLineUp"
let copy_line_down = cmd "copyLineDown"
let insert_newline = cmd "insertNewline"
let insert_newline_keep_indent = cmd "insertNewlineKeepIndent"
let insert_newline_and_indent = cmd "insertNewlineAndIndent"
let insert_blank_line = cmd "insertBlankLine"

(* -- Indentation ----------------------------------------------------------- *)

let indent_selection = cmd "indentSelection"
let indent_more = cmd "indentMore"
let indent_less = cmd "indentLess"
let insert_tab = cmd "insertTab"
let toggle_tab_focus_mode = cmd "toggleTabFocusMode"
let temporarily_set_tab_focus_mode = cmd "temporarilySetTabFocusMode"

(* -- Comments -------------------------------------------------------------- *)

let toggle_comment = cmd "toggleComment"
let toggle_line_comment = cmd "toggleLineComment"
let line_comment = cmd "lineComment"
let line_uncomment = cmd "lineUncomment"
let toggle_block_comment = cmd "toggleBlockComment"
let block_comment = cmd "blockComment"
let block_uncomment = cmd "blockUncomment"
let toggle_block_comment_by_line = cmd "toggleBlockCommentByLine"

(* -- History ----------------------------------------------------------------
   isolateHistory's annotation payload is a fixed string union; invertedEffects
   is a facet whose value is a function ([Transaction.t -> state_effect list]),
   hand-converted the way Cm_state's own change_filter/transaction_filter are
   (there is no Conv combinator for "a function from these types"; see
   src/view/DESIGN.md's friction notes, which already flagged this gap). *)

let isolate_history_conv : [ `After | `Before | `Full ] Conv.t =
  {
    Conv.to_jv =
      (function
      | `After -> Jv.of_string "after"
      | `Before -> Jv.of_string "before"
      | `Full -> Jv.of_string "full");
    of_jv =
      (fun jv ->
        match Jv.to_string jv with
        | "after" -> `After
        | "before" -> `Before
        | "full" -> `Full
        | _ -> Conv.invalid "is_isolate_history" jv);
  }

let is_isolate_history : [ `After | `Before | `Full ] AnnotationType.t =
  AnnotationType.of_jv isolate_history_conv
    (Jv.get (Lazy.force pkg) "isolateHistory")

let inverted_effects_conv : (Transaction.t -> state_effect list) Conv.t =
  {
    Conv.to_jv =
      (fun f ->
        Jv.callback ~arity:1 (fun (tr : Jv.t) ->
            Jv.of_list StateEffect.to_jv (f (Transaction.of_jv tr))));
    of_jv =
      (fun jv (tr : Transaction.t) ->
        Jv.to_list StateEffect.of_jv (Jv.apply jv [| Transaction.to_jv tr |]));
  }

let inverted_effects : (Transaction.t -> state_effect list, Jv.t) Facet.t =
  Facet.of_jv inverted_effects_conv Conv.jv
    (Jv.get (Lazy.force pkg) "invertedEffects")

let history ?min_depth ?new_group_delay ?join_to_event () : Extension.t =
  let o = Jv.obj [||] in
  Jv.Int.set_if_some o "minDepth" min_depth;
  Jv.Int.set_if_some o "newGroupDelay" new_group_delay;
  Jv.set_if_some o "joinToEvent"
    (Option.map
       (fun f ->
         Jv.callback ~arity:2 (fun (tr : Jv.t) (is_adjacent : Jv.t) ->
             Jv.of_bool (f (Transaction.of_jv tr) (Jv.to_bool is_adjacent))))
       join_to_event);
  Extension.of_jv (Jv.call (Lazy.force pkg) "history" [| o |])

let history_field : Jv.t = Jv.get (Lazy.force pkg) "historyField"
let undo = cmd "undo"
let redo = cmd "redo"
let undo_selection = cmd "undoSelection"
let redo_selection = cmd "redoSelection"

let undo_depth (state : EditorState.t) : int =
  Jv.to_int (Jv.call (Lazy.force pkg) "undoDepth" [| EditorState.to_jv state |])

let redo_depth (state : EditorState.t) : int =
  Jv.to_int (Jv.call (Lazy.force pkg) "redoDepth" [| EditorState.to_jv state |])

let history_keymap = keymap_of "historyKeymap"

(* -- Keymaps ----------------------------------------------------------------- *)

let emacs_style_keymap = keymap_of "emacsStyleKeymap"
let standard_keymap = keymap_of "standardKeymap"
let default_keymap = keymap_of "defaultKeymap"

let indent_with_tab : KeyBinding.t =
  KeyBinding.of_jv (Jv.get (Lazy.force pkg) "indentWithTab")
