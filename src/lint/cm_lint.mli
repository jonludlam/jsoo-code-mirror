(** {{:https://codemirror.net/docs/ref/#lint} \@codemirror/lint}: diagnostics,
    lint markers, an optional gutter, and a panel for showing problems found in
    the document. *)

open Cm_state
open Cm_view

(** {{:https://codemirror.net/docs/ref/#lint.Severity} lint.Severity}. A plain
    string union in CodeMirror, not a class; given a module of its own for
    consistency with the other bound enumerations ({!Cm_state.MapMode},
    {!Cm_view.Direction}, {!Cm_view.BlockType}). *)
module Severity : sig
  type t = Hint | Info | Warning | Error
end

(** {{:https://codemirror.net/docs/ref/#lint.Action} lint.Action} *)
module Action : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create : name:string -> (EditorView.t -> from:int -> to_:int -> unit) -> t
  (** [create ~name apply]: [apply] is called with the diagnostic's {i current}
      position, which may have moved since the diagnostic was created, due to
      editing. *)

  val name : t -> string
end

(** {{:https://codemirror.net/docs/ref/#lint.Diagnostic} lint.Diagnostic} *)
module Diagnostic : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create :
    from:int ->
    to_:int ->
    severity:Severity.t ->
    message:string ->
    ?source:string ->
    ?mark_class:string ->
    ?actions:Action.t list ->
    ?rendered_message:(EditorView.t -> Brr.El.t) ->
    unit ->
    t
  (** [rendered_message] is CodeMirror's [renderMessage], whose JavaScript
      return type is [Node]; only the element case is bound, as elsewhere in
      this library (see {!Cm_view.WidgetType.make}'s [to_dom]). *)

  val from : t -> int
  val to_ : t -> int
  val severity : t -> Severity.t
  val message : t -> string
  val source : t -> string option
  val mark_class : t -> string option
  val actions : t -> Action.t list option
end

type diagnostic_filter = Diagnostic.t list -> EditorState.t -> Diagnostic.t list
(** CodeMirror's [DiagnosticFilter]. *)

val linter :
  ?delay:int ->
  ?needs_refresh:(ViewUpdate.t -> bool) ->
  ?marker_filter:diagnostic_filter ->
  ?tooltip_filter:diagnostic_filter ->
  ?hide_on:(Transaction.t -> from:int -> to_:int -> bool option) ->
  ?auto_panel:bool ->
  (EditorView.t -> Diagnostic.t list Fut.t) ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#lint.linter} lint.linter}. The source
    may produce its diagnostics synchronously; wrap the result with [Fut.return]
    (see {!Cm_view.hover_tooltip}). [hide_on] returning [None] is JavaScript's
    [null]: fall back to the default behavior. *)

val lint_gutter :
  ?hover_time:int ->
  ?marker_filter:diagnostic_filter ->
  ?tooltip_filter:diagnostic_filter ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#lint.lintGutter} lint.lintGutter} *)

val lint_keymap : KeyBinding.t list
(** {{:https://codemirror.net/docs/ref/#lint.lintKeymap} lint.lintKeymap} *)

val open_lint_panel : command
(** {{:https://codemirror.net/docs/ref/#lint.openLintPanel} lint.openLintPanel}
*)

val close_lint_panel : command
(** {{:https://codemirror.net/docs/ref/#lint.closeLintPanel}
     lint.closeLintPanel} *)

val next_diagnostic : command
(** {{:https://codemirror.net/docs/ref/#lint.nextDiagnostic}
     lint.nextDiagnostic} *)

val previous_diagnostic : command
(** {{:https://codemirror.net/docs/ref/#lint.previousDiagnostic}
     lint.previousDiagnostic} *)

val set_diagnostics : EditorState.t -> Diagnostic.t list -> TransactionSpec.t
(** {{:https://codemirror.net/docs/ref/#lint.setDiagnostics}
     lint.setDiagnostics} *)

val set_diagnostics_effect : Diagnostic.t list StateEffectType.t
(** {{:https://codemirror.net/docs/ref/#lint.setDiagnosticsEffect}
     lint.setDiagnosticsEffect} *)

val diagnostic_count : EditorState.t -> int
(** {{:https://codemirror.net/docs/ref/#lint.diagnosticCount}
     lint.diagnosticCount} *)

val for_each_diagnostic :
  EditorState.t -> (Diagnostic.t -> from:int -> to_:int -> unit) -> unit
(** {{:https://codemirror.net/docs/ref/#lint.forEachDiagnostic}
     lint.forEachDiagnostic} *)

val force_linting : EditorView.t -> unit
(** {{:https://codemirror.net/docs/ref/#lint.forceLinting} lint.forceLinting} *)
