(* An editor talking to a language server. The server is a few dozen
   lines of OCaml in this page, behind a [Transport], so the example needs
   no backend: it answers [initialize], hover, completion and definition
   requests, and publishes a warning for every TODO in the document. A
   real page would put a server in a worker, or across a WebSocket, behind
   the same three functions. *)

open Brr
open Cm_state
open Cm_view
open Cm_lsp_client

let file_uri = "file:///workspace/main.ml"

(* -- the server ------------------------------------------------------- *)

module Server = struct
  let text = ref ""
  let subscribers : (Jstr.t -> unit) list ref = ref []

  (* Messages arrive later, as they would from a worker or a socket. *)
  let emit msg =
    let s = Json.encode msg in
    ignore
      (G.set_timeout ~ms:0 (fun () -> List.iter (fun f -> f s) !subscribers))

  let respond id result =
    emit
      (Jv.obj
         [| ("jsonrpc", Jv.of_string "2.0"); ("id", id); ("result", result) |])

  let notify method_ params =
    emit
      (Jv.obj
         [|
           ("jsonrpc", Jv.of_string "2.0");
           ("method", Jv.of_string method_);
           ("params", params);
         |])

  (* Offsets and LSP positions, for a document of ASCII lines. *)
  let offset_of (p : Position.t) =
    let lines = String.split_on_char '\n' !text in
    let rec go n acc = function
      | l :: rest when n < p.line -> go (n + 1) (acc + String.length l + 1) rest
      | _ -> acc + p.character
    in
    go 0 0 lines

  let position_of off =
    let before = String.sub !text 0 off in
    let line = List.length (String.split_on_char '\n' before) - 1 in
    let bol =
      match String.rindex_opt before '\n' with Some i -> i + 1 | None -> 0
    in
    Position.{ line; character = off - bol }

  let range from to_ =
    Jv.obj
      [|
        ("start", Position.to_jv (position_of from));
        ("end", Position.to_jv (position_of to_));
      |]

  let is_word c =
    match c with
    | 'a' .. 'z' | 'A' .. 'Z' | '_' | '0' .. '9' -> true
    | _ -> false

  let word_at off =
    let n = String.length !text in
    let a = ref off and b = ref off in
    while !a > 0 && is_word !text.[!a - 1] do
      decr a
    done;
    while !b < n && is_word !text.[!b] do
      incr b
    done;
    if !a = !b then None else Some (String.sub !text !a (!b - !a))

  let find sub =
    let n = String.length sub in
    let rec go i =
      if i + n > String.length !text then None
      else if String.sub !text i n = sub then Some i
      else go (i + 1)
    in
    go 0

  let publish_diagnostics () =
    let rec todos i acc =
      if i + 4 > String.length !text then List.rev acc
      else if String.sub !text i 4 = "TODO" then
        let d =
          Jv.obj
            [|
              ("range", range i (i + 4));
              ("severity", Jv.of_int 2);
              ("message", Jv.of_string "TODO left in the code");
            |]
        in
        todos (i + 4) (d :: acc)
      else todos (i + 1) acc
    in
    notify "textDocument/publishDiagnostics"
      (Jv.obj
         [|
           ("uri", Jv.of_string file_uri);
           ("diagnostics", Jv.of_list Fun.id (todos 0 []));
         |])

  let position params = Position.of_jv (Jv.get params "position")

  let handle msg =
    let method_ = Jv.find msg "method" |> Option.map Jv.to_string in
    let params = Jv.get msg "params" in
    let id = Jv.get msg "id" in
    match method_ with
    | Some "initialize" ->
        respond id
          (Jv.obj
             [|
               ( "capabilities",
                 Jv.obj
                   [|
                     ("textDocumentSync", Jv.of_int 1);
                     ("hoverProvider", Jv.true');
                     ("completionProvider", Jv.obj [||]);
                     ("definitionProvider", Jv.true');
                   |] );
             |])
    | Some "textDocument/didOpen" ->
        text := Jv.to_string (Jv.get (Jv.get params "textDocument") "text");
        publish_diagnostics ()
    | Some "textDocument/didChange" ->
        let changes = Jv.to_jv_array (Jv.get params "contentChanges") in
        Array.iter (fun c -> text := Jv.to_string (Jv.get c "text")) changes;
        publish_diagnostics ()
    | Some "textDocument/hover" -> (
        match word_at (offset_of (position params)) with
        | None -> respond id Jv.null
        | Some w ->
            respond id
              (Jv.obj
                 [|
                   ( "contents",
                     Jv.obj
                       [|
                         ("kind", Jv.of_string "markdown");
                         ( "value",
                           Jv.of_string (Printf.sprintf "**%s**, a name" w) );
                       |] );
                 |]))
    | Some "textDocument/completion" ->
        let item l = Jv.obj [| ("label", Jv.of_string l) |] in
        respond id (Jv.of_list item [ "greeting"; "shout"; "print_endline" ])
    | Some "textDocument/definition" -> (
        match word_at (offset_of (position params)) with
        | None -> respond id Jv.null
        | Some w -> (
            match find ("let " ^ w) with
            | None -> respond id Jv.null
            | Some i ->
                let from = i + 4 in
                respond id
                  (Jv.obj
                     [|
                       ("uri", Jv.of_string file_uri);
                       ("range", range from (from + String.length w));
                     |])))
    | Some _ when not (Jv.is_undefined id) -> respond id Jv.null
    | _ -> ()

  let transport =
    Transport.create
      ~send:(fun s ->
        match Json.decode s with Ok msg -> handle msg | Error _ -> ())
      ~subscribe:(fun f -> subscribers := f :: !subscribers)
      ~unsubscribe:(fun f ->
        subscribers := List.filter (fun g -> g != f) !subscribers)
end

(* -- the client and the editor ----------------------------------------- *)

let client =
  LSPClient.create
    ~config:
      (LSPClientConfig.create ~root_uri:"file:///workspace"
         ~extensions:(language_server_extensions ())
         ())
    ()

let () = LSPClient.connect client Server.transport

let doc_text =
  "let greeting = \"hello\"\n\
   (* TODO: say more *)\n\
   let shout = greeting ^ \"!\"\n"

let container = El.div ~at:At.[ id (Jstr.v "editor") ] []
let () = El.append_children (Document.body G.document) [ container ]

let view =
  let extensions =
    Extension.of_list
      [
        line_numbers ();
        Facet.of_ keymap jump_to_definition_keymap;
        LSPClient.plugin ~language_id:"ocaml" client file_uri;
      ]
  in
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~state:
           (EditorState.create
              ~config:(EditorStateConfig.create ~doc:doc_text ~extensions ())
              ())
         ~parent:container ())
    ()

(* -- self-check ----------------------------------------------------------- *)

open Example_check

(* A second client whose workspace is OCaml, as a page holding several
   editors on one file, or files without editors, would write. It is never
   connected: this only watches CodeMirror call into it. *)
let custom_workspace () =
  let files = ref [] and log = ref [] in
  let workspace client =
    Workspace.create
      ~files:(fun () -> !files)
      ~sync_files:(fun () -> [])
      ~open_file:(fun uri ~language_id v ->
        log := ("open " ^ uri) :: !log;
        let doc = EditorState.doc (EditorView.state v) in
        files :=
          [
            WorkspaceFile.create ~uri ~language_id ~version:0 ~doc
              ~get_view:(fun ?main:_ () -> Some v)
              ();
          ])
      ~close_file:(fun uri _ ->
        log := ("close " ^ uri) :: !log;
        files := [])
      client
  in
  let client =
    LSPClient.create ~config:(LSPClientConfig.create ~workspace ()) ()
  in
  let uri = "file:///workspace/other.ml" in
  let v =
    EditorView.create
      ~config:
        (EditorViewConfig.create
           ~state:
             (EditorState.create
                ~config:
                  (EditorStateConfig.create ~doc:"let x = 1"
                     ~extensions:
                       (LSPClient.plugin ~language_id:"ocaml" client uri)
                     ())
                ())
           ())
      ()
  in
  let ws = LSPClient.workspace client in
  let open_ok =
    List.map WorkspaceFile.uri (Workspace.files ws) = [ uri ]
    && Workspace.get_file ws uri <> None
    && Workspace.sync_files ws = []
    && Workspace.client ws == client
  in
  EditorView.destroy v;
  open_ok && List.rev !log = [ "open " ^ uri; "close " ^ uri ]

let head () =
  SelectionRange.head
    (EditorSelection.main (EditorState.selection (EditorView.state view)))

let has_warning () = by_class view "cm-lintRange-warning" <> []
let ( let* ) = Fut.bind

let () =
  keep [ view ];
  Fut.await
    (let* init = LSPClient.initializing client in
     note "the client initializes over the transport" (Result.is_ok init);
     check "the server's capabilities are known" (fun () ->
         LSPClient.server_capabilities client <> None);
     check "the editor has the plugin, for this file" (fun () ->
         match LSPPlugin.get view with
         | Some p -> LSPPlugin.uri p = file_uri
         | None -> false);
     check "the workspace has the file open" (fun () ->
         List.map WorkspaceFile.uri
           (Workspace.files (LSPClient.workspace client))
         = [ file_uri ]);
     check "offsets and positions round-trip" (fun () ->
         let p = Option.get (LSPPlugin.get view) in
         (LSPPlugin.to_position p 30 = Position.{ line = 1; character = 7 })
         && LSPPlugin.from_position p (LSPPlugin.to_position p 30) = 30);
     let* warned = wait_for ~tries:60 has_warning in
     note "published diagnostics show as lint warnings" warned;
     let* hover =
       LSPClient.sync client;
       LSPClient.request client "textDocument/hover"
         (Jv.obj
            [|
              ("textDocument", Jv.obj [| ("uri", Jv.of_string file_uri) |]);
              ("position", Position.to_jv Position.{ line = 0; character = 6 });
            |])
     in
     check "a request gets the server's answer, rendered from Markdown"
       (fun () ->
         match hover with
         | Ok r ->
             let v = Jv.to_string (Jv.get (Jv.get r "contents") "value") in
             let html =
               LSPPlugin.doc_to_html
                 (Option.get (LSPPlugin.get view))
                 (`Markup (MarkupKind.Markdown, v))
             in
             contains ~sub:"<strong>greeting</strong>" html
         | Error _ -> false);
     let ctx =
       Cm_autocomplete.CompletionContext.create (EditorView.state view) ~pos:4
         ~explicit:true ~view ()
     in
     let* completions = server_completion_source ctx in
     check "the completion source lists the server's items" (fun () ->
         match completions with
         | Some r ->
             List.map Cm_autocomplete.Completion.label
               (Cm_autocomplete.CompletionResult.options r)
             = [ "greeting"; "shout"; "print_endline" ]
         | None -> false);
     (* On [greeting] in the last line; its definition is at offset 4. *)
     select view 58 58;
     ignore (jump_to_definition view);
     let* jumped = wait_for ~tries:60 (fun () -> head () = 4) in
     note "jump_to_definition moves to the let" jumped;
     let* mapped =
       LSPClient.with_mapping client (fun m ->
           EditorView.dispatch view
             (TransactionSpec.create
                ~changes:(ChangeSpec.insert ~at:0 "(* hi *) ")
                ());
           Fut.return (WorkspaceMapping.map_pos m file_uri 4))
     in
     note "a workspace mapping follows an edit made during a request"
       (mapped = Some 13);
     LSPClient.disconnect client;
     check "disconnecting unsubscribes from the transport" (fun () ->
         !Server.subscribers = []);
     check "a workspace written in OCaml is told when editors open and close"
       custom_workspace;
     Fut.return ())
    report
