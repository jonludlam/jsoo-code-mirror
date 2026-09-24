# Cm_lsp_client

Bind `@codemirror/lsp-client`
(node_modules/@codemirror/lsp-client/dist/index.d.ts). Depends on
Cm_state, Cm_view, Cm_language (a config callback returns a `Language`)
and Cm_autocomplete (it exports a `CompletionSource`); its bundle also
reads lint's global, for `setDiagnostics`.

Every export is bound except the two the package deprecates,
`languageServerSupport` and `LSPPlugin.create`, whose replacements
(`languageServerExtensions`, `LSPClient.plugin`) are bound.

The shape:

- `LSPClient`, `LSPClientConfig`, `LSPPlugin`, `Workspace`,
  `WorkspaceFile`, `WorkspaceMapping`, `Transport` and
  `LSPClientExtension` are modules named as CodeMirror names them.
- Commands (`jump_to_definition`, `rename_symbol`, ...) are `command`
  values and keymaps are `KeyBinding.t list`, as in Cm_commands.
- LSP's own payloads (request params and results, notification params,
  capabilities, initialization options) are `Jv.t`. They are JSON of
  whatever shape the method defines, `any` in the JavaScript types, and
  the package never interprets them. The two LSP types the package itself
  reads and writes are typed: `Position` (a record) and `MarkupKind`.

## Questions and friction

- **`Transport.unsubscribe` needs identity.** JavaScript unsubscribes by
  passing back the very function it subscribed. An OCaml binding that
  wraps the handler afresh in each direction (as the binding in
  voodoos/jsoo-code-mirror does) hands `unsubscribe` a function that was
  never subscribed, and the handler stays registered. `Transport.create`
  keeps the OCaml function made for each JavaScript handler and passes the
  same one to `unsubscribe`, so an implementation can remove it with `==`.
  The example checks this.
- **Messages are `Jstr.t`.** Everywhere else a JavaScript string is an
  OCaml `string`. Transport messages are whole JSON-RPC messages, often
  large, that usually come from or go straight to a JavaScript API (a
  worker's `postMessage`, a WebSocket), so converting each one to UTF-8
  and back is wasted work. Worth a line in CONVENTIONS.md if another
  package meets the same case.
- **`extensions` is a union, typed as one module.**
  `LSPClientConfig.extensions` is `(Extension | LSPClientExtension)[]`,
  and `languageServerExtensions` returns the same mixed array. Rather than
  a polymorphic variant, which could not be decoded from what
  `languageServerExtensions` returns (a plain `Extension` can be any
  object, so the two cases are not distinguishable), `LSPClientExtension.t`
  is the union, with `of_extension` as the injection. A plain
  `LSPClientExtension` has no separate type; nothing needs one.
- **Subclassing `Workspace`.** As `WidgetType.make` does, `Workspace.create`
  instantiates the JavaScript class and replaces members on the instance:
  the four abstract ones are labelled arguments, the overridable ones
  optional. `files` is a property the client reads directly, so it becomes
  a getter; `WorkspaceFile.set_version` and `set_doc` exist because a
  workspace's `sync_files` has to update the files it reports.
- **`WorkspaceMapping.map_pos` returns `int option` always**, as
  `ChangeDesc.map_pos` does, rather than splitting on whether a mode was
  given; JavaScript's `null` only happens with one.
- **`docToHTML` defaults to plain text**, not Markdown, when given a bare
  string. The `.d.ts` does not say; the implementation does.
- **`LSPClient.connected` stays `true` after `disconnect`.** It is
  `!!this.transport`, and `disconnect` unsubscribes without clearing the
  transport. Documented rather than papered over.
- **Testing without a server.** The example runs a small language server
  in OCaml behind a `Transport`, answering `initialize`, hover, completion
  and definition and publishing diagnostics, which is enough to exercise
  requests, notifications, the Markdown renderer, the completion source,
  a command that goes to the server and back, a workspace mapping, and a
  workspace written in OCaml. It has no worker or socket in between, so
  its timing is kinder than a real server's.
