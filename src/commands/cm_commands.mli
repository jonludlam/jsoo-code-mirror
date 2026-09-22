(** {{:https://codemirror.net/docs/ref/#commands} \@codemirror/commands}: cursor
    and selection motion, deletion, line manipulation, indentation, comment
    toggling, the undo history, and the default key bindings. Depends on
    {!Cm_state} and {!Cm_view} (both opened below); no value here mentions a
    [Cm_language] type, but linking [code-mirror.language] in is still required
    at run time - the JavaScript bundle's indentation commands ([indent_more],
    [indent_less], [insert_newline_and_indent], [indent_selection],
    [indent_with_tab]) call into [\@codemirror/language] through a shim that
    reads it off the [__CM__language] global, which is only set once that
    package's own bundle has run. See DESIGN.md's friction notes.

    Every value here binds a JavaScript [Command] or [StateCommand]. The two are
    typed differently in [index.d.ts] ([Command] takes a whole [EditorView],
    [StateCommand] destructures [\{state, dispatch\}]), but since every value
    this package hands one to is already a {!Cm_view.editor_view} - which
    structurally has both - a single [command_of_jv] wrapper invokes either kind
    the same way. So, as [\@codemirror/search]'s bindings already found, there
    is no separate [state_command] type: everything below is a plain
    {!Cm_view.command} ([editor_view -> bool]). *)

open Cm_state
open Cm_view

(** {1 Cursor motion} *)

val cursor_char_left : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorCharLeft}
     commands.cursorCharLeft}. Move the selection one character to the left
    (backward in left-to-right text, forward in right-to-left text). *)

val cursor_char_right : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorCharRight}
     commands.cursorCharRight} *)

val cursor_char_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorCharForward}
     commands.cursorCharForward} *)

val cursor_char_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorCharBackward}
     commands.cursorCharBackward} *)

val cursor_char_forward_logical : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorCharForwardLogical}
     commands.cursorCharForwardLogical}. Logical (non-text-direction-aware)
    string index order. *)

val cursor_char_backward_logical : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorCharBackwardLogical}
     commands.cursorCharBackwardLogical} *)

val cursor_group_left : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorGroupLeft}
     commands.cursorGroupLeft}. One group of word or non-word (but non-space)
    characters. *)

val cursor_group_right : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorGroupRight}
     commands.cursorGroupRight} *)

val cursor_group_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorGroupForward}
     commands.cursorGroupForward} *)

val cursor_group_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorGroupBackward}
     commands.cursorGroupBackward} *)

val cursor_group_forward_win : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorGroupForwardWin}
     commands.cursorGroupForwardWin}. Default Windows style: moves to the start
    of the next group. *)

val cursor_subword_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorSubwordForward}
     commands.cursorSubwordForward}. One group or camel-case subword. *)

val cursor_subword_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorSubwordBackward}
     commands.cursorSubwordBackward} *)

val cursor_syntax_left : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorSyntaxLeft}
     commands.cursorSyntaxLeft}. Over the next syntactic element. *)

val cursor_syntax_right : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorSyntaxRight}
     commands.cursorSyntaxRight} *)

val cursor_line_up : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorLineUp}
     commands.cursorLineUp} *)

val cursor_line_down : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorLineDown}
     commands.cursorLineDown} *)

val cursor_page_up : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorPageUp}
     commands.cursorPageUp} *)

val cursor_page_down : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorPageDown}
     commands.cursorPageDown} *)

val cursor_line_boundary_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorLineBoundaryForward}
     commands.cursorLineBoundaryForward}. To the next line wrap point, or the
    end of the line. *)

val cursor_line_boundary_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorLineBoundaryBackward}
     commands.cursorLineBoundaryBackward}. To the previous wrap point, or the
    start of the line - via the end of the indentation first, if any. *)

val cursor_line_boundary_left : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorLineBoundaryLeft}
     commands.cursorLineBoundaryLeft} *)

val cursor_line_boundary_right : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorLineBoundaryRight}
     commands.cursorLineBoundaryRight} *)

val cursor_line_start : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorLineStart}
     commands.cursorLineStart} *)

val cursor_line_end : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorLineEnd}
     commands.cursorLineEnd} *)

val cursor_doc_start : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorDocStart}
     commands.cursorDocStart} *)

val cursor_doc_end : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorDocEnd}
     commands.cursorDocEnd} *)

val cursor_matching_bracket : command
(** {{:https://codemirror.net/docs/ref/#commands.cursorMatchingBracket}
     commands.cursorMatchingBracket}. Moves to the bracket matching the one the
    cursor is on, if any. *)

(** {1 Selection} *)

val select_matching_bracket : command
(** {{:https://codemirror.net/docs/ref/#commands.selectMatchingBracket}
     commands.selectMatchingBracket}. Extends the selection to the matching
    bracket. *)

val select_char_left : command
(** {{:https://codemirror.net/docs/ref/#commands.selectCharLeft}
     commands.selectCharLeft}. Moves the head, leaving the anchor in place. *)

val select_char_right : command
(** {{:https://codemirror.net/docs/ref/#commands.selectCharRight}
     commands.selectCharRight} *)

val select_char_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.selectCharForward}
     commands.selectCharForward} *)

val select_char_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.selectCharBackward}
     commands.selectCharBackward} *)

val select_char_forward_logical : command
(** {{:https://codemirror.net/docs/ref/#commands.selectCharForwardLogical}
     commands.selectCharForwardLogical} *)

val select_char_backward_logical : command
(** {{:https://codemirror.net/docs/ref/#commands.selectCharBackwardLogical}
     commands.selectCharBackwardLogical} *)

val select_group_left : command
(** {{:https://codemirror.net/docs/ref/#commands.selectGroupLeft}
     commands.selectGroupLeft} *)

val select_group_right : command
(** {{:https://codemirror.net/docs/ref/#commands.selectGroupRight}
     commands.selectGroupRight} *)

val select_group_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.selectGroupForward}
     commands.selectGroupForward} *)

val select_group_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.selectGroupBackward}
     commands.selectGroupBackward} *)

val select_group_forward_win : command
(** {{:https://codemirror.net/docs/ref/#commands.selectGroupForwardWin}
     commands.selectGroupForwardWin} *)

val select_subword_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.selectSubwordForward}
     commands.selectSubwordForward} *)

val select_subword_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.selectSubwordBackward}
     commands.selectSubwordBackward} *)

val select_syntax_left : command
(** {{:https://codemirror.net/docs/ref/#commands.selectSyntaxLeft}
     commands.selectSyntaxLeft} *)

val select_syntax_right : command
(** {{:https://codemirror.net/docs/ref/#commands.selectSyntaxRight}
     commands.selectSyntaxRight} *)

val select_line_up : command
(** {{:https://codemirror.net/docs/ref/#commands.selectLineUp}
     commands.selectLineUp} *)

val select_line_down : command
(** {{:https://codemirror.net/docs/ref/#commands.selectLineDown}
     commands.selectLineDown} *)

val select_page_up : command
(** {{:https://codemirror.net/docs/ref/#commands.selectPageUp}
     commands.selectPageUp} *)

val select_page_down : command
(** {{:https://codemirror.net/docs/ref/#commands.selectPageDown}
     commands.selectPageDown} *)

val select_line_boundary_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.selectLineBoundaryForward}
     commands.selectLineBoundaryForward} *)

val select_line_boundary_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.selectLineBoundaryBackward}
     commands.selectLineBoundaryBackward} *)

val select_line_boundary_left : command
(** {{:https://codemirror.net/docs/ref/#commands.selectLineBoundaryLeft}
     commands.selectLineBoundaryLeft} *)

val select_line_boundary_right : command
(** {{:https://codemirror.net/docs/ref/#commands.selectLineBoundaryRight}
     commands.selectLineBoundaryRight} *)

val select_line_start : command
(** {{:https://codemirror.net/docs/ref/#commands.selectLineStart}
     commands.selectLineStart} *)

val select_line_end : command
(** {{:https://codemirror.net/docs/ref/#commands.selectLineEnd}
     commands.selectLineEnd} *)

val select_doc_start : command
(** {{:https://codemirror.net/docs/ref/#commands.selectDocStart}
     commands.selectDocStart} *)

val select_doc_end : command
(** {{:https://codemirror.net/docs/ref/#commands.selectDocEnd}
     commands.selectDocEnd} *)

val select_all : command
(** {{:https://codemirror.net/docs/ref/#commands.selectAll} commands.selectAll}
*)

val select_line : command
(** {{:https://codemirror.net/docs/ref/#commands.selectLine}
     commands.selectLine}. Expands the selection to cover whole lines. *)

val select_parent_syntax : command
(** {{:https://codemirror.net/docs/ref/#commands.selectParentSyntax}
     commands.selectParentSyntax}. Selects the next syntactic construct larger
    than the current selection; only useful once a language builds a full syntax
    tree. *)

val simplify_selection : command
(** {{:https://codemirror.net/docs/ref/#commands.simplifySelection}
     commands.simplifySelection}. Multiple ranges reduce to the main one;
    otherwise a non-empty selection collapses to a cursor. *)

(** {1 Deletion} *)

val delete_char_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteCharBackward}
     commands.deleteCharBackward}. The selection, or the character or
    indentation unit before the cursor. *)

val delete_char_backward_strict : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteCharBackwardStrict}
     commands.deleteCharBackwardStrict}. Like {!delete_char_backward} but never
    deletes a whole indentation unit at once. *)

val delete_char_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteCharForward}
     commands.deleteCharForward} *)

val delete_group_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteGroupBackward}
     commands.deleteGroupBackward} *)

val delete_group_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteGroupForward}
     commands.deleteGroupForward} *)

val delete_to_line_end : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteToLineEnd}
     commands.deleteToLineEnd}. At the end of the line already, deletes the line
    break instead. *)

val delete_to_line_start : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteToLineStart}
     commands.deleteToLineStart} *)

val delete_line_boundary_backward : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteLineBoundaryBackward}
     commands.deleteLineBoundaryBackward} *)

val delete_line_boundary_forward : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteLineBoundaryForward}
     commands.deleteLineBoundaryForward} *)

val delete_trailing_whitespace : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteTrailingWhitespace}
     commands.deleteTrailingWhitespace} *)

val delete_line : command
(** {{:https://codemirror.net/docs/ref/#commands.deleteLine}
     commands.deleteLine} *)

(** {1 Line manipulation} *)

val split_line : command
(** {{:https://codemirror.net/docs/ref/#commands.splitLine} commands.splitLine}.
    Replaces each selection range with a line break. *)

val transpose_chars : command
(** {{:https://codemirror.net/docs/ref/#commands.transposeChars}
     commands.transposeChars} *)

val move_line_up : command
(** {{:https://codemirror.net/docs/ref/#commands.moveLineUp}
     commands.moveLineUp} *)

val move_line_down : command
(** {{:https://codemirror.net/docs/ref/#commands.moveLineDown}
     commands.moveLineDown} *)

val copy_line_up : command
(** {{:https://codemirror.net/docs/ref/#commands.copyLineUp}
     commands.copyLineUp} *)

val copy_line_down : command
(** {{:https://codemirror.net/docs/ref/#commands.copyLineDown}
     commands.copyLineDown} *)

val insert_newline : command
(** {{:https://codemirror.net/docs/ref/#commands.insertNewline}
     commands.insertNewline} *)

val insert_newline_keep_indent : command
(** {{:https://codemirror.net/docs/ref/#commands.insertNewlineKeepIndent}
     commands.insertNewlineKeepIndent} *)

val insert_newline_and_indent : command
(** {{:https://codemirror.net/docs/ref/#commands.insertNewlineAndIndent}
     commands.insertNewlineAndIndent}. Uses the indentation service; see
    [@codemirror/language]. *)

val insert_blank_line : command
(** {{:https://codemirror.net/docs/ref/#commands.insertBlankLine}
     commands.insertBlankLine} *)

(** {1 Indentation} *)

val indent_selection : command
(** {{:https://codemirror.net/docs/ref/#commands.indentSelection}
     commands.indentSelection}. Auto-indents the selected lines via the
    indentation service facet from [@codemirror/language]. *)

val indent_more : command
(** {{:https://codemirror.net/docs/ref/#commands.indentMore}
     commands.indentMore} *)

val indent_less : command
(** {{:https://codemirror.net/docs/ref/#commands.indentLess}
     commands.indentLess} *)

val insert_tab : command
(** {{:https://codemirror.net/docs/ref/#commands.insertTab} commands.insertTab}.
    A tab character at the cursor, or {!indent_more} over a non-empty selection.
*)

val toggle_tab_focus_mode : command
(** {{:https://codemirror.net/docs/ref/#commands.toggleTabFocusMode}
     commands.toggleTabFocusMode}. Enables or disables
    [EditorView.setTabFocusMode], letting Tab move focus out of the editor. *)

val temporarily_set_tab_focus_mode : command
(** {{:https://codemirror.net/docs/ref/#commands.temporarilySetTabFocusMode}
     commands.temporarilySetTabFocusMode}. Tab-focus mode for two seconds, or
    until another key is pressed. *)

(** {1 Comments}

    [CommentTokens] ([\{block?: \{open, close\}, line?: string\}]) is not bound
    as a distinct type: it is [\@codemirror/state] language data, read under a
    ["commentTokens"] key via {!Cm_state.EditorState.language_data} (or a
    language's own data facet), not a value this package constructs or returns.
*)

val toggle_comment : command
(** {{:https://codemirror.net/docs/ref/#commands.toggleComment}
     commands.toggleComment}. Line comments if available, else block comments.
*)

val toggle_line_comment : command
(** {{:https://codemirror.net/docs/ref/#commands.toggleLineComment}
     commands.toggleLineComment} *)

val line_comment : command
(** {{:https://codemirror.net/docs/ref/#commands.lineComment}
     commands.lineComment} *)

val line_uncomment : command
(** {{:https://codemirror.net/docs/ref/#commands.lineUncomment}
     commands.lineUncomment} *)

val toggle_block_comment : command
(** {{:https://codemirror.net/docs/ref/#commands.toggleBlockComment}
     commands.toggleBlockComment} *)

val block_comment : command
(** {{:https://codemirror.net/docs/ref/#commands.blockComment}
     commands.blockComment} *)

val block_uncomment : command
(** {{:https://codemirror.net/docs/ref/#commands.blockUncomment}
     commands.blockUncomment} *)

val toggle_block_comment_by_line : command
(** {{:https://codemirror.net/docs/ref/#commands.toggleBlockCommentByLine}
     commands.toggleBlockCommentByLine}. Comments or uncomments the lines around
    the current selection, using block comments. *)

(** {1 History} *)

val is_isolate_history : [ `After | `Before | `Full ] AnnotationType.t
(** {{:https://codemirror.net/docs/ref/#commands.isolateHistory}
     commands.isolateHistory}. A transaction annotation that keeps it from being
    merged with adjacent transactions in the undo history: [`Before] blocks
    merging with earlier transactions, [`After] with later ones, [`Full] both.
*)

val inverted_effects : (Transaction.t -> state_effect list, Jv.t) Facet.t
(** {{:https://codemirror.net/docs/ref/#commands.invertedEffects}
     commands.invertedEffects}. Registers functions that, given a transaction,
    compute the effects the history should re-apply when inverting it - the way
    to make a custom {!Cm_state.StateEffect.t} undoable. *)

val history :
  ?min_depth:int ->
  ?new_group_delay:int ->
  ?join_to_event:(Transaction.t -> bool -> bool) ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#commands.history} commands.history}.
    [join_to_event tr is_adjacent] decides whether [tr] joins the existing undo
    event when close enough in time to it. *)

val history_field : Jv.t
(** {{:https://codemirror.net/docs/ref/#commands.historyField}
     commands.historyField}. The [StateField] CodeMirror stores the history in.
    Left as a raw handle: {!Cm_state.StateField.of_jv} could wrap it, but its
    value, CodeMirror's private history state, has no OCaml type, and this
    binding's {!Cm_state.EditorState.to_json}/[from_json] do not take the
    per-field dictionary ([fields]) that is the only place JavaScript itself
    threads this value through. *)

val undo : command
(** {{:https://codemirror.net/docs/ref/#commands.undo} commands.undo}. Undoes a
    single group of history events; [false] if none is available. *)

val redo : command
(** {{:https://codemirror.net/docs/ref/#commands.redo} commands.redo} *)

val undo_selection : command
(** {{:https://codemirror.net/docs/ref/#commands.undoSelection}
     commands.undoSelection}. Undoes a change or a selection change. *)

val redo_selection : command
(** {{:https://codemirror.net/docs/ref/#commands.redoSelection}
     commands.redoSelection} *)

val undo_depth : EditorState.t -> int
(** {{:https://codemirror.net/docs/ref/#commands.undoDepth} commands.undoDepth}
*)

val redo_depth : EditorState.t -> int
(** {{:https://codemirror.net/docs/ref/#commands.redoDepth} commands.redoDepth}
*)

val history_keymap : KeyBinding.t list
(** {{:https://codemirror.net/docs/ref/#commands.historyKeymap}
     commands.historyKeymap}. Mod-z: {!undo}. Mod-y (Mod-Shift-z on macOS,
    Ctrl-Shift-z on Linux): {!redo}. Mod-u: {!undo_selection}. Alt-u
    (Mod-Shift-u on macOS): {!redo_selection}. *)

(** {1 Keymaps} *)

val emacs_style_keymap : KeyBinding.t list
(** {{:https://codemirror.net/docs/ref/#commands.emacsStyleKeymap}
     commands.emacsStyleKeymap}. The Emacs-style bindings macOS uses by default.
*)

val standard_keymap : KeyBinding.t list
(** {{:https://codemirror.net/docs/ref/#commands.standardKeymap}
     commands.standardKeymap}. Platform-standard bindings, including
    {!emacs_style_keymap} (with [key] moved to [mac]). *)

val default_keymap : KeyBinding.t list
(** {{:https://codemirror.net/docs/ref/#commands.defaultKeymap}
     commands.defaultKeymap}. {!standard_keymap} plus syntax-aware motion, line
    movement, {!toggle_comment}, {!indent_less}/{!indent_more} and more; see the
    reference for the exact table. *)

val indent_with_tab : KeyBinding.t
(** {{:https://codemirror.net/docs/ref/#commands.indentWithTab}
     commands.indentWithTab}. Binds Tab to {!indent_more} and Shift-Tab to
    {!indent_less}. Not part of {!default_keymap} - install separately, and see
    the CodeMirror reference's note on keyboard-accessibility trade-offs before
    doing so. *)
