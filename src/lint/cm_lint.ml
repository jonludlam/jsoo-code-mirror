open Cm_state
open Cm_view

let pkg = lazy (Jv.get Jv.global "__CM__lint")

module Severity = struct
  type t = Hint | Info | Warning | Error
end

let severity_to_string = function
  | Severity.Hint -> "hint"
  | Severity.Info -> "info"
  | Severity.Warning -> "warning"
  | Severity.Error -> "error"

let severity_of_string = function
  | "hint" -> Severity.Hint
  | "info" -> Severity.Info
  | "warning" -> Severity.Warning
  | "error" -> Severity.Error
  | s -> Conv.invalid "Severity" (Jv.of_string s)

module Action = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ~name (apply : EditorView.t -> from:int -> to_:int -> unit) : t =
    let wrapped (view : Jv.t) (from : Jv.t) (to_ : Jv.t) =
      apply (EditorView.of_jv view) ~from:(Jv.to_int from) ~to_:(Jv.to_int to_)
    in
    let o = Jv.obj [||] in
    Jv.Jstr.set o "name" (Jstr.v name);
    Jv.set o "apply" (Jv.callback ~arity:3 wrapped);
    o

  let name t = Jv.Jstr.get t "name" |> Jstr.to_string
end

module Diagnostic = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ~from ~to_ ~severity ~message ?source ?mark_class ?actions
      ?rendered_message () : t =
    let o = Jv.obj [||] in
    Jv.Int.set o "from" from;
    Jv.Int.set o "to" to_;
    Jv.Jstr.set o "severity" (Jstr.v (severity_to_string severity));
    Jv.Jstr.set o "message" (Jstr.v message);
    Jv.set_if_some o "source" (Option.map Jv.of_string source);
    Jv.set_if_some o "markClass" (Option.map Jv.of_string mark_class);
    (match actions with
    | None -> ()
    | Some l -> Jv.set o "actions" (Jv.of_list Action.to_jv l));
    Option.iter
      (fun f ->
        Jv.set o "renderMessage"
          (Jv.callback ~arity:1 (fun (view : Jv.t) ->
               Brr.El.to_jv (f (EditorView.of_jv view)))))
      rendered_message;
    o

  let from t = Jv.Int.get t "from"
  let to_ t = Jv.Int.get t "to"

  let severity t =
    Jv.Jstr.get t "severity" |> Jstr.to_string |> severity_of_string

  let message t = Jv.Jstr.get t "message" |> Jstr.to_string
  let source t = Jv.Jstr.find t "source" |> Option.map Jstr.to_string
  let mark_class t = Jv.Jstr.find t "markClass" |> Option.map Jstr.to_string
  let actions t = Jv.find t "actions" |> Option.map (Jv.to_list Action.of_jv)
end

type diagnostic_filter = Diagnostic.t list -> EditorState.t -> Diagnostic.t list

let filter_to_jv (f : diagnostic_filter) =
  Jv.callback ~arity:2 (fun (diags : Jv.t) (state : Jv.t) ->
      Jv.of_list Diagnostic.to_jv
        (f (Jv.to_list Diagnostic.of_jv diags) (EditorState.of_jv state)))

let linter ?delay ?needs_refresh ?marker_filter ?tooltip_filter ?hide_on
    ?auto_panel (source : EditorView.t -> Diagnostic.t list Fut.t) : Extension.t
    =
  let wrapped (view : Jv.t) =
    let fut = source (EditorView.of_jv view) in
    let result_fut =
      Fut.map (fun diags -> Ok (Jv.of_list Diagnostic.to_jv diags)) fut
    in
    Fut.to_promise ~ok:Fun.id result_fut
  in
  let o = Jv.obj [||] in
  Jv.Int.set_if_some o "delay" delay;
  Option.iter
    (fun f ->
      Jv.set o "needsRefresh"
        (Jv.callback ~arity:1 (fun (u : Jv.t) ->
             Jv.of_bool (f (ViewUpdate.of_jv u)))))
    needs_refresh;
  Option.iter (fun f -> Jv.set o "markerFilter" (filter_to_jv f)) marker_filter;
  Option.iter
    (fun f -> Jv.set o "tooltipFilter" (filter_to_jv f))
    tooltip_filter;
  Option.iter
    (fun f ->
      Jv.set o "hideOn"
        (Jv.callback ~arity:3 (fun (tr : Jv.t) (from : Jv.t) (to_ : Jv.t) ->
             match
               f (Transaction.of_jv tr) ~from:(Jv.to_int from)
                 ~to_:(Jv.to_int to_)
             with
             | None -> Jv.null
             | Some b -> Jv.of_bool b)))
    hide_on;
  Jv.Bool.set_if_some o "autoPanel" auto_panel;
  Extension.of_jv
    (Jv.call (Lazy.force pkg) "linter" [| Jv.callback ~arity:1 wrapped; o |])

let lint_gutter ?hover_time ?marker_filter ?tooltip_filter () : Extension.t =
  let o = Jv.obj [||] in
  Jv.Int.set_if_some o "hoverTime" hover_time;
  Option.iter (fun f -> Jv.set o "markerFilter" (filter_to_jv f)) marker_filter;
  Option.iter
    (fun f -> Jv.set o "tooltipFilter" (filter_to_jv f))
    tooltip_filter;
  Extension.of_jv (Jv.call (Lazy.force pkg) "lintGutter" [| o |])

let lint_keymap : KeyBinding.t list =
  Jv.get (Lazy.force pkg) "lintKeymap" |> Jv.to_list KeyBinding.of_jv

let open_lint_panel : command =
 fun view ->
  Jv.apply (Jv.get (Lazy.force pkg) "openLintPanel") [| EditorView.to_jv view |]
  |> Jv.to_bool

let close_lint_panel : command =
 fun view ->
  Jv.apply
    (Jv.get (Lazy.force pkg) "closeLintPanel")
    [| EditorView.to_jv view |]
  |> Jv.to_bool

let next_diagnostic : command =
 fun view ->
  Jv.apply
    (Jv.get (Lazy.force pkg) "nextDiagnostic")
    [| EditorView.to_jv view |]
  |> Jv.to_bool

let previous_diagnostic : command =
 fun view ->
  Jv.apply
    (Jv.get (Lazy.force pkg) "previousDiagnostic")
    [| EditorView.to_jv view |]
  |> Jv.to_bool

let set_diagnostics (st : EditorState.t) (diags : Diagnostic.t list) :
    TransactionSpec.t =
  Jv.call (Lazy.force pkg) "setDiagnostics"
    [| EditorState.to_jv st; Jv.of_list Diagnostic.to_jv diags |]
  |> TransactionSpec.of_jv

let set_diagnostics_effect : Diagnostic.t list StateEffectType.t =
  StateEffectType.of_jv
    (Conv.list Diagnostic.conv)
    (Jv.get (Lazy.force pkg) "setDiagnosticsEffect")

let diagnostic_count (st : EditorState.t) : int =
  Jv.call (Lazy.force pkg) "diagnosticCount" [| EditorState.to_jv st |]
  |> Jv.to_int

let for_each_diagnostic (st : EditorState.t)
    (f : Diagnostic.t -> from:int -> to_:int -> unit) : unit =
  let wrapped (d : Jv.t) (from : Jv.t) (to_ : Jv.t) =
    f (Diagnostic.of_jv d) ~from:(Jv.to_int from) ~to_:(Jv.to_int to_)
  in
  Jv.call (Lazy.force pkg) "forEachDiagnostic"
    [| EditorState.to_jv st; Jv.callback ~arity:3 wrapped |]
  |> ignore

let force_linting (view : EditorView.t) : unit =
  Jv.call (Lazy.force pkg) "forceLinting" [| EditorView.to_jv view |] |> ignore
