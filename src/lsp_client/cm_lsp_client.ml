open Cm_state
open Cm_view

let pkg = lazy (Jv.get Jv.global "__CM__lsp_client")
let get name = Jv.get (Lazy.force pkg) name

type lsp_client = Jv.t
type workspace = Jv.t

let opt_int = Jv.of_option ~none:Jv.undefined Jv.of_int

let map_mode_to_int = function
  | MapMode.Simple -> 0
  | MapMode.Track_del -> 1
  | MapMode.Track_before -> 2
  | MapMode.Track_after -> 3

let nullable f v = if Jv.is_none v then None else Some (f v)
let or_null f = function None -> Jv.null | Some v -> f v

let notification_handlers_to_jv handlers =
  let o = Jv.obj [||] in
  List.iter
    (fun (method_, handler) ->
      Jv.set o method_
        (Jv.callback ~arity:2 (fun client params ->
             Jv.of_bool (handler client params))))
    handlers;
  o

module Position = struct
  type t = { line : int; character : int }

  let to_jv { line; character } =
    Jv.obj [| ("line", Jv.of_int line); ("character", Jv.of_int character) |]

  let of_jv jv =
    { line = Jv.Int.get jv "line"; character = Jv.Int.get jv "character" }

  let conv = Conv.{ to_jv; of_jv }
end

module MarkupKind = struct
  type t = Plaintext | Markdown

  let to_jv = function
    | Plaintext -> Jv.of_string "plaintext"
    | Markdown -> Jv.of_string "markdown"
end

module Transport = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let create ~send ~subscribe ~unsubscribe : t =
    (* JavaScript unsubscribes by passing back the handler it subscribed;
       keep the OCaml function made for each one so [unsubscribe] gets the
       same function [subscribe] did. *)
    let wrapped = ref [] in
    let is h (h', _) = Jv.strict_equal h h' in
    let o = Jv.obj [||] in
    Jv.set o "send" (Jv.callback ~arity:1 (fun msg -> send (Jv.to_jstr msg)));
    Jv.set o "subscribe"
      (Jv.callback ~arity:1 (fun handler ->
           let f msg = ignore (Jv.apply handler [| Jv.of_jstr msg |]) in
           wrapped := (handler, f) :: !wrapped;
           subscribe f));
    Jv.set o "unsubscribe"
      (Jv.callback ~arity:1 (fun handler ->
           match List.find_opt (is handler) !wrapped with
           | None -> ()
           | Some (_, f) ->
               wrapped := List.filter (fun w -> not (is handler w)) !wrapped;
               unsubscribe f));
    o
end

module WorkspaceFile = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ~uri ~language_id ~version ~doc ~get_view () : t =
    Jv.obj
      [|
        ("uri", Jv.of_string uri);
        ("languageId", Jv.of_string language_id);
        ("version", Jv.of_int version);
        ("doc", Text.to_jv doc);
        ( "getView",
          Jv.callback ~arity:1 (fun main ->
              let main = nullable EditorView.of_jv main in
              or_null EditorView.to_jv (get_view ?main ())) );
      |]

  let uri t = Jv.to_string (Jv.get t "uri")
  let language_id t = Jv.to_string (Jv.get t "languageId")
  let version t = Jv.Int.get t "version"
  let doc t = Text.of_jv (Jv.get t "doc")

  let get_view ?main t =
    let args =
      match main with None -> [||] | Some v -> [| EditorView.to_jv v |]
    in
    nullable EditorView.of_jv (Jv.call t "getView" args)

  let set_version t v = Jv.Int.set t "version" v
  let set_doc t d = Jv.set t "doc" (Text.to_jv d)
end

module WorkspaceFileUpdate = struct
  type t = { file : WorkspaceFile.t; prev_doc : Text.t; changes : ChangeSet.t }

  let to_jv { file; prev_doc; changes } =
    Jv.obj
      [|
        ("file", WorkspaceFile.to_jv file);
        ("prevDoc", Text.to_jv prev_doc);
        ("changes", ChangeSet.to_jv changes);
      |]

  let of_jv jv =
    {
      file = WorkspaceFile.of_jv (Jv.get jv "file");
      prev_doc = Text.of_jv (Jv.get jv "prevDoc");
      changes = ChangeSet.of_jv (Jv.get jv "changes");
    }

  let conv = Conv.{ to_jv; of_jv }
end

module WorkspaceMapping = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let get_mapping t uri =
    nullable ChangeDesc.of_jv (Jv.call t "getMapping" [| Jv.of_string uri |])

  (* JavaScript's default [assoc] is -1; a [mode] has to come after it. *)
  let assoc_mode assoc mode =
    match mode with
    | None -> [| opt_int assoc |]
    | Some m ->
        [|
          Jv.of_int (Option.value ~default:(-1) assoc);
          Jv.of_int (map_mode_to_int m);
        |]

  let map_pos ?assoc ?mode t uri pos =
    Jv.call t "mapPos"
      (Array.append
         [| Jv.of_string uri; Jv.of_int pos |]
         (assoc_mode assoc mode))
    |> nullable Jv.to_int

  let map_position ?assoc ?mode t uri pos =
    Jv.call t "mapPosition"
      (Array.append
         [| Jv.of_string uri; Position.to_jv pos |]
         (assoc_mode assoc mode))
    |> nullable Jv.to_int

  let destroy t = ignore (Jv.call t "destroy" [||])
end

module LSPClientExtension = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?client_capabilities ?notification_handlers ?editor_extension () :
      t =
    let o = Jv.obj [||] in
    Jv.set_if_some o "clientCapabilities" client_capabilities;
    Jv.set_if_some o "notificationHandlers"
      (Option.map notification_handlers_to_jv notification_handlers);
    Jv.set_if_some o "editorExtension"
      (Option.map Extension.to_jv editor_extension);
    o

  let of_extension e : t = Extension.to_jv e
end

module LSPClientConfig = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?root_uri ?initialization_options ?workspace ?timeout
      ?sanitize_html ?highlight_language ?notification_handlers
      ?unhandled_notification ?extensions () : t =
    let o = Jv.obj [||] in
    Jv.set_if_some o "rootUri" (Option.map Jv.of_string root_uri);
    Jv.set_if_some o "initializationOptions" initialization_options;
    Option.iter
      (fun f ->
        Jv.set o "workspace" (Jv.callback ~arity:1 (fun client -> f client)))
      workspace;
    Jv.Int.set_if_some o "timeout" timeout;
    Option.iter
      (fun f ->
        Jv.set o "sanitizeHTML"
          (Jv.callback ~arity:1 (fun html ->
               Jv.of_string (f (Jv.to_string html)))))
      sanitize_html;
    Option.iter
      (fun f ->
        Jv.set o "highlightLanguage"
          (Jv.callback ~arity:1 (fun name ->
               or_null Cm_language.Language.to_jv (f (Jv.to_string name)))))
      highlight_language;
    Jv.set_if_some o "notificationHandlers"
      (Option.map notification_handlers_to_jv notification_handlers);
    Option.iter
      (fun f ->
        Jv.set o "unhandledNotification"
          (Jv.callback ~arity:3 (fun client method_ params ->
               f client (Jv.to_string method_) params)))
      unhandled_notification;
    Jv.set_if_some o "extensions" (Option.map (Jv.of_list Fun.id) extensions);
    o
end

module Workspace = struct
  type t = workspace

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?get_file ?request_file ?connected ?disconnected ?update_file
      ?display_file ~files ~sync_files ~open_file ~close_file client : t =
    let w = Jv.new' (get "Workspace") [| client |] in
    (* JavaScript reads [files] as a property, not a method. *)
    let getter =
      Jv.obj
        [|
          ( "get",
            Jv.callback ~arity:1 (fun () ->
                Jv.of_list WorkspaceFile.to_jv (files ())) );
          ("configurable", Jv.true');
        |]
    in
    ignore
      (Jv.call
         (Jv.get Jv.global "Object")
         "defineProperty"
         [| w; Jv.of_string "files"; getter |]);
    let meth name arity f = Jv.set w name (Jv.callback ~arity f) in
    meth "syncFiles" 1 (fun () ->
        Jv.of_list WorkspaceFileUpdate.to_jv (sync_files ()));
    Jv.set w "openFile"
      (Jv.callback ~arity:3 (fun uri language_id view ->
           open_file (Jv.to_string uri) ~language_id:(Jv.to_string language_id)
             (EditorView.of_jv view)));
    Jv.set w "closeFile"
      (Jv.callback ~arity:2 (fun uri view ->
           close_file (Jv.to_string uri) (EditorView.of_jv view)));
    Option.iter
      (fun f ->
        meth "getFile" 1 (fun uri ->
            or_null WorkspaceFile.to_jv (f (Jv.to_string uri))))
      get_file;
    Option.iter
      (fun f ->
        meth "requestFile" 1 (fun uri ->
            Async.promise_of_fut
              (or_null WorkspaceFile.to_jv)
              (f (Jv.to_string uri))))
      request_file;
    Option.iter (fun f -> meth "connected" 1 (fun () -> f ())) connected;
    Option.iter (fun f -> meth "disconnected" 1 (fun () -> f ())) disconnected;
    Option.iter
      (fun f ->
        Jv.set w "updateFile"
          (Jv.callback ~arity:2 (fun uri spec ->
               f (Jv.to_string uri) (TransactionSpec.of_jv spec))))
      update_file;
    Option.iter
      (fun f ->
        meth "displayFile" 1 (fun uri ->
            Async.promise_of_fut (or_null EditorView.to_jv)
              (f (Jv.to_string uri))))
      display_file;
    w

  let client t : lsp_client = Jv.get t "client"
  let files t = Jv.to_list WorkspaceFile.of_jv (Jv.get t "files")

  let get_file t uri =
    nullable WorkspaceFile.of_jv (Jv.call t "getFile" [| Jv.of_string uri |])

  let sync_files t =
    Jv.to_list WorkspaceFileUpdate.of_jv (Jv.call t "syncFiles" [||])

  let request_file t uri =
    Async.fut_of_promise
      (nullable WorkspaceFile.of_jv)
      (Jv.call t "requestFile" [| Jv.of_string uri |])

  let open_file t uri ~language_id view =
    ignore
      (Jv.call t "openFile"
         [| Jv.of_string uri; Jv.of_string language_id; EditorView.to_jv view |])

  let close_file t uri view =
    ignore (Jv.call t "closeFile" [| Jv.of_string uri; EditorView.to_jv view |])

  let connected t = ignore (Jv.call t "connected" [||])
  let disconnected t = ignore (Jv.call t "disconnected" [||])

  let update_file t uri spec =
    ignore
      (Jv.call t "updateFile"
         [| Jv.of_string uri; TransactionSpec.to_jv spec |])

  let display_file t uri =
    Async.fut_of_promise
      (nullable EditorView.of_jv)
      (Jv.call t "displayFile" [| Jv.of_string uri |])
end

module LSPClient = struct
  type t = lsp_client

  include (Jv.Id : Jv.CONV with type t := t)

  let create ?config () : t =
    let args =
      match config with None -> [||] | Some c -> [| LSPClientConfig.to_jv c |]
    in
    Jv.new' (get "LSPClient") args

  let workspace t = Workspace.of_jv (Jv.get t "workspace")
  let server_capabilities t = nullable Fun.id (Jv.get t "serverCapabilities")

  let initializing t =
    Fut.of_promise ~ok:(fun _ -> ()) (Jv.get t "initializing")

  let connected t = Jv.Bool.get t "connected"

  let connect t transport =
    ignore (Jv.call t "connect" [| Transport.to_jv transport |])

  let disconnect t = ignore (Jv.call t "disconnect" [||])

  let plugin ?language_id t file_uri =
    let args =
      match language_id with
      | None -> [| Jv.of_string file_uri |]
      | Some id -> [| Jv.of_string file_uri; Jv.of_string id |]
    in
    Extension.of_jv (Jv.call t "plugin" args)

  let did_open t file =
    ignore (Jv.call t "didOpen" [| WorkspaceFile.to_jv file |])

  let did_close t uri = ignore (Jv.call t "didClose" [| Jv.of_string uri |])

  let request t method_ params =
    Jv.call t "request" [| Jv.of_string method_; params |]
    |> Fut.of_promise ~ok:Fun.id

  let notification t method_ params =
    ignore (Jv.call t "notification" [| Jv.of_string method_; params |])

  let cancel_request t params = ignore (Jv.call t "cancelRequest" [| params |])

  let workspace_mapping t =
    WorkspaceMapping.of_jv (Jv.call t "workspaceMapping" [||])

  let with_mapping t f =
    let f =
      Jv.callback ~arity:1 (fun mapping ->
          Async.promise_of_fut Jv.Id.to_jv (f (WorkspaceMapping.of_jv mapping)))
    in
    Async.fut_of_promise Jv.Id.of_jv (Jv.call t "withMapping" [| f |])

  let sync t = ignore (Jv.call t "sync" [||])
end

module LSPPlugin = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let get view =
    nullable Fun.id
      (Jv.call (get "LSPPlugin") "get" [| EditorView.to_jv view |])

  let view t = EditorView.of_jv (Jv.get t "view")
  let client t = LSPClient.of_jv (Jv.get t "client")
  let uri t = Jv.to_string (Jv.get t "uri")

  let doc_to_html ?default_kind t value =
    let value =
      match value with
      | `String s -> Jv.of_string s
      | `Markup (kind, s) ->
          Jv.obj
            [| ("kind", MarkupKind.to_jv kind); ("value", Jv.of_string s) |]
    in
    let args =
      match default_kind with
      | None -> [| value |]
      | Some k -> [| value; MarkupKind.to_jv k |]
    in
    Jv.to_string (Jv.call t "docToHTML" args)

  let with_doc args doc =
    match doc with
    | None -> args
    | Some d -> Array.append args [| Text.to_jv d |]

  let to_position ?doc t pos =
    Position.of_jv (Jv.call t "toPosition" (with_doc [| Jv.of_int pos |] doc))

  let from_position ?doc t pos =
    Jv.to_int (Jv.call t "fromPosition" (with_doc [| Position.to_jv pos |] doc))

  let report_error t message err =
    ignore (Jv.call t "reportError" [| Jv.of_string message; err |])

  let synced_doc t = Text.of_jv (Jv.get t "syncedDoc")
  let unsynced_changes t = ChangeSet.of_jv (Jv.get t "unsyncedChanges")
  let clear t = ignore (Jv.call t "clear" [||])
end

let command name : command =
 fun view -> Jv.to_bool (Jv.apply (get name) [| EditorView.to_jv view |])

let keymap_of name = Jv.to_list KeyBinding.of_jv (get name)

let server_completion ?override ?valid_for () =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "override" override;
  Jv.set_if_some o "validFor" valid_for;
  Extension.of_jv (Jv.apply (get "serverCompletion") [| o |])

let server_completion_source : Cm_autocomplete.completion_source =
 fun ctx ->
  Jv.apply
    (get "serverCompletionSource")
    [| Cm_autocomplete.CompletionContext.to_jv ctx |]
  |> Jv.Promise.resolve
  |> Async.fut_of_promise (nullable Cm_autocomplete.CompletionResult.of_jv)

let hover_tooltips ?hover_time () =
  let o = Jv.obj [||] in
  Jv.Int.set_if_some o "hoverTime" hover_time;
  Extension.of_jv (Jv.apply (get "hoverTooltips") [| o |])

let format_document = command "formatDocument"
let format_keymap = keymap_of "formatKeymap"
let rename_symbol = command "renameSymbol"
let rename_keymap = keymap_of "renameKeymap"
let show_signature_help = command "showSignatureHelp"
let next_signature = command "nextSignature"
let prev_signature = command "prevSignature"
let signature_keymap = keymap_of "signatureKeymap"

let signature_help ?keymap () =
  let o = Jv.obj [||] in
  Jv.Bool.set_if_some o "keymap" keymap;
  Extension.of_jv (Jv.apply (get "signatureHelp") [| o |])

let jump_to_definition = command "jumpToDefinition"
let jump_to_declaration = command "jumpToDeclaration"
let jump_to_type_definition = command "jumpToTypeDefinition"
let jump_to_implementation = command "jumpToImplementation"
let jump_to_definition_keymap = keymap_of "jumpToDefinitionKeymap"
let find_references = command "findReferences"
let close_reference_panel = command "closeReferencePanel"
let find_references_keymap = keymap_of "findReferencesKeymap"

let server_diagnostics () =
  LSPClientExtension.of_jv (Jv.apply (get "serverDiagnostics") [||])

let language_server_extensions () =
  Jv.apply (get "languageServerExtensions") [||]
  |> Jv.to_list LSPClientExtension.of_jv
