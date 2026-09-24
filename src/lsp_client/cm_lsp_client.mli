(** {{:https://codemirror.net/docs/ref/#lsp-client} \@codemirror/lsp-client}:
    talk to a language server over a transport the page supplies, and show what
    it says (completions, hover documentation, diagnostics, signature help,
    renames, references and jumps to definitions) in editors.

    LSP requests, responses and notification parameters are JSON of whatever
    shape the method defines, so they are [Jv.t] here, as [any] is in the
    JavaScript types; the positions and documentation this package itself reads
    and writes are typed. *)

open Cm_state
open Cm_view

(* Forward declarations, equated below. *)
type lsp_client
type workspace

(** An LSP
    {{:https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#position}
     Position}: a zero-based line and a UTF-16 column. *)
module Position : sig
  type t = { line : int; character : int }

  val to_jv : t -> Jv.t
  val of_jv : Jv.t -> t
  val conv : t Conv.t
end

(** An LSP
    {{:https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#markupContent}
     MarkupKind}: how to read a documentation string. *)
module MarkupKind : sig
  type t = Plaintext | Markdown
end

(** {{:https://codemirror.net/docs/ref/#lsp-client.Transport}
     lsp-client.Transport}: how messages reach the server and come back.
    Messages are JSON text without LSP headers. They are [Jstr.t], not [string],
    because they are often large and usually go straight to or from a JavaScript
    API (a worker's [postMessage], a WebSocket). *)
module Transport : sig
  type t

  include Jv.CONV with type t := t

  val create :
    send:(Jstr.t -> unit) ->
    subscribe:((Jstr.t -> unit) -> unit) ->
    unsubscribe:((Jstr.t -> unit) -> unit) ->
    t
  (** [unsubscribe] is given the very function [subscribe] was given for the
      same JavaScript handler, so it can find it with [==]. *)
end

(** {{:https://codemirror.net/docs/ref/#lsp-client.WorkspaceFile}
     lsp-client.WorkspaceFile}: a file open in a workspace. *)
module WorkspaceFile : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create :
    uri:string ->
    language_id:string ->
    version:int ->
    doc:Text.t ->
    get_view:(?main:EditorView.t -> unit -> EditorView.t option) ->
    unit ->
    t
  (** For a {!Workspace.create} of your own. *)

  val uri : t -> string
  val language_id : t -> string
  val version : t -> int

  val doc : t -> Text.t
  (** The document at {!version}, not the editor's current one. *)

  val get_view : ?main:EditorView.t -> t -> EditorView.t option

  val set_version : t -> int -> unit
  (** With {!set_doc}, what a workspace's [sync_files] does to a file it reports
      as changed. *)

  val set_doc : t -> Text.t -> unit
end

(** What a workspace's [sync_files] reports for each file that changed. *)
module WorkspaceFileUpdate : sig
  type t = { file : WorkspaceFile.t; prev_doc : Text.t; changes : ChangeSet.t }

  val to_jv : t -> Jv.t
  val of_jv : Jv.t -> t
  val conv : t Conv.t
end

(** {{:https://codemirror.net/docs/ref/#lsp-client.WorkspaceMapping}
     lsp-client.WorkspaceMapping}: positions from a request, read against the
    documents as they are now. *)
module WorkspaceMapping : sig
  type t

  include Jv.CONV with type t := t

  val get_mapping : t -> string -> ChangeDesc.t option
  (** [None] for a document that is not open. *)

  val map_pos :
    ?assoc:int -> ?mode:MapMode.t -> t -> string -> int -> int option
  (** [None] only when [mode] says the position was deleted, as
      {!Cm_state.ChangeDesc.map_pos}. *)

  val map_position :
    ?assoc:int -> ?mode:MapMode.t -> t -> string -> Position.t -> int option

  val destroy : t -> unit
  (** Every mapping from {!LSPClient.workspace_mapping} needs this; those
      {!LSPClient.with_mapping} makes are destroyed for you. *)
end

(** {{:https://codemirror.net/docs/ref/#lsp-client.LSPClientExtension}
     lsp-client.LSPClientExtension}, or a plain editor extension: the two things
    {!LSPClientConfig.create}'s [extensions] list can hold. *)
module LSPClientExtension : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?client_capabilities:Jv.t ->
    ?notification_handlers:(string * (lsp_client -> Jv.t -> bool)) list ->
    ?editor_extension:Extension.t ->
    unit ->
    t

  val of_extension : Extension.t -> t
  (** A plain editor extension, included in every {!LSPClient.plugin}. *)
end

(** {{:https://codemirror.net/docs/ref/#lsp-client.LSPClientConfig}
     lsp-client.LSPClientConfig} *)
module LSPClientConfig : sig
  type t

  include Jv.CONV with type t := t

  val create :
    ?root_uri:string ->
    ?initialization_options:Jv.t ->
    ?workspace:(lsp_client -> workspace) ->
    ?timeout:int ->
    ?sanitize_html:(string -> string) ->
    ?highlight_language:(string -> Cm_language.Language.t option) ->
    ?notification_handlers:(string * (lsp_client -> Jv.t -> bool)) list ->
    ?unhandled_notification:(lsp_client -> string -> Jv.t -> unit) ->
    ?extensions:LSPClientExtension.t list ->
    unit ->
    t
  (** A notification handler returning [true] has handled the notification;
      [false] lets the next one try. *)
end

(** {{:https://codemirror.net/docs/ref/#lsp-client.Workspace}
     lsp-client.Workspace}: the files the client has open. *)
module Workspace : sig
  type t = workspace

  include Jv.CONV with type t := t

  val create :
    ?get_file:(string -> WorkspaceFile.t option) ->
    ?request_file:(string -> WorkspaceFile.t option Fut.t) ->
    ?connected:(unit -> unit) ->
    ?disconnected:(unit -> unit) ->
    ?update_file:(string -> TransactionSpec.t -> unit) ->
    ?display_file:(string -> EditorView.t option Fut.t) ->
    files:(unit -> WorkspaceFile.t list) ->
    sync_files:(unit -> WorkspaceFileUpdate.t list) ->
    open_file:(string -> language_id:string -> EditorView.t -> unit) ->
    close_file:(string -> EditorView.t -> unit) ->
    lsp_client ->
    t
  (** Subclassing [Workspace], for {!LSPClientConfig.create}'s [workspace]: the
      four labelled functions are its abstract members, and each optional one
      replaces the default. *)

  val client : t -> lsp_client
  val files : t -> WorkspaceFile.t list
  val get_file : t -> string -> WorkspaceFile.t option
  val sync_files : t -> WorkspaceFileUpdate.t list
  val request_file : t -> string -> WorkspaceFile.t option Fut.t
  val open_file : t -> string -> language_id:string -> EditorView.t -> unit
  val close_file : t -> string -> EditorView.t -> unit
  val connected : t -> unit
  val disconnected : t -> unit
  val update_file : t -> string -> TransactionSpec.t -> unit
  val display_file : t -> string -> EditorView.t option Fut.t
end

(** {{:https://codemirror.net/docs/ref/#lsp-client.LSPClient}
     lsp-client.LSPClient} *)
module LSPClient : sig
  type t = lsp_client

  include Jv.CONV with type t := t

  val create : ?config:LSPClientConfig.t -> unit -> t
  val workspace : t -> Workspace.t

  val server_capabilities : t -> Jv.t option
  (** [None] until the client is connected and initialized. *)

  val initializing : t -> (unit, Jv.Error.t) result Fut.t
  (** Read again after {!disconnect}, which replaces the promise. *)

  val connected : t -> bool

  val connect : t -> Transport.t -> unit
  (** Starts the initialization exchange; {!initializing} says when it is done.
  *)

  val disconnect : t -> unit
  (** Unsubscribes from the transport. {!connected} stays [true] afterwards, as
      in JavaScript, where it only asks whether a transport was ever given. *)

  val plugin : ?language_id:string -> t -> string -> Extension.t
  (** [plugin client file_uri]: what an editor needs to take part. Without
      [language_id], the editor's language's name is the ID. *)

  val did_open : t -> WorkspaceFile.t -> unit
  val did_close : t -> string -> unit

  val request : t -> string -> Jv.t -> (Jv.t, Jv.Error.t) result Fut.t
  (** [request client method_ params]. Call {!sync} first unless the method does
      not read documents. *)

  val notification : t -> string -> Jv.t -> unit

  val cancel_request : t -> Jv.t -> unit
  (** Cancels the request whose [params] are this very value. *)

  val workspace_mapping : t -> WorkspaceMapping.t
  val with_mapping : t -> (WorkspaceMapping.t -> 'a Fut.t) -> 'a Fut.t
  val sync : t -> unit
end

(** {{:https://codemirror.net/docs/ref/#lsp-client.LSPPlugin}
     lsp-client.LSPPlugin}: what {!LSPClient.plugin} puts in an editor.
    [LSPPlugin.create], deprecated for {!LSPClient.plugin}, is not bound. *)
module LSPPlugin : sig
  type t

  include Jv.CONV with type t := t

  val get : EditorView.t -> t option
  val view : t -> EditorView.t
  val client : t -> LSPClient.t
  val uri : t -> string

  val doc_to_html :
    ?default_kind:MarkupKind.t ->
    t ->
    [ `String of string | `Markup of MarkupKind.t * string ] ->
    string
  (** A documentation value from the server, as HTML. [`String] is read as
      [default_kind], plain text if not given. *)

  val to_position : ?doc:Text.t -> t -> int -> Position.t
  val from_position : ?doc:Text.t -> t -> Position.t -> int
  val report_error : t -> string -> Jv.t -> unit
  val synced_doc : t -> Text.t
  val unsynced_changes : t -> ChangeSet.t
  val clear : t -> unit
end

(** {1 Features}

    Each is also in {!language_server_extensions}. *)

val server_completion : ?override:bool -> ?valid_for:Jv.t -> unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#lsp-client.serverCompletion}
     lsp-client.serverCompletion}. [valid_for] is a JavaScript [RegExp], as
    {!Cm_autocomplete.CompletionResult.create}'s [`Regexp]. *)

val server_completion_source : Cm_autocomplete.completion_source
(** {{:https://codemirror.net/docs/ref/#lsp-client.serverCompletionSource}
     lsp-client.serverCompletionSource} *)

val hover_tooltips : ?hover_time:int -> unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#lsp-client.hoverTooltips}
     lsp-client.hoverTooltips} *)

val format_document : command
val format_keymap : KeyBinding.t list
val rename_symbol : command
val rename_keymap : KeyBinding.t list
val show_signature_help : command
val next_signature : command
val prev_signature : command
val signature_keymap : KeyBinding.t list

val signature_help : ?keymap:bool -> unit -> Extension.t
(** {{:https://codemirror.net/docs/ref/#lsp-client.signatureHelp}
     lsp-client.signatureHelp} *)

val jump_to_definition : command
val jump_to_declaration : command
val jump_to_type_definition : command
val jump_to_implementation : command
val jump_to_definition_keymap : KeyBinding.t list
val find_references : command
val close_reference_panel : command
val find_references_keymap : KeyBinding.t list

val server_diagnostics : unit -> LSPClientExtension.t
(** {{:https://codemirror.net/docs/ref/#lsp-client.serverDiagnostics}
     lsp-client.serverDiagnostics}: shows [textDocument/publishDiagnostics]
    through {!Cm_lint}. *)

val language_server_extensions : unit -> LSPClientExtension.t list
(** {{:https://codemirror.net/docs/ref/#lsp-client.languageServerExtensions}
     lsp-client.languageServerExtensions}: every feature above, for
    {!LSPClientConfig.create}'s [extensions]. [languageServerSupport],
    deprecated for this, is not bound. *)
