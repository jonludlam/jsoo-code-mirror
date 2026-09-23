# Cm_collab

Bind `@codemirror/collab`
(node_modules/@codemirror/collab/dist/index.d.ts). Depends only on
Cm_state. The whole package is seven exports, so bind all of them.

The shape to follow:

```ocaml
(** {{:https://codemirror.net/docs/ref/#collab} @codemirror/collab}:
    operational-transform collaborative editing against a central
    authority. *)

open Cm_state

(** {{:https://codemirror.net/docs/ref/#collab.Update} collab.Update}: one
    client's changes, as the authority passes them around. *)
module Update : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t
  val create : ?effects:StateEffect.t list -> changes:ChangeSet.t -> client_id:string -> unit -> t
  val changes : t -> ChangeSet.t
  val effects : t -> StateEffect.t list
  val client_id : t -> string

  val origin : t -> Transaction.t option
  (** Only on the updates {!sendable_updates} returns: the transaction
      that made this update, before any remapping. *)
end

val collab :
  ?start_version:int -> ?client_id:string ->
  ?shared_effects:(Transaction.t -> StateEffect.t list) -> unit -> Extension.t

val receive_updates : EditorState.t -> Update.t list -> Transaction.t
val sendable_updates : EditorState.t -> Update.t list
val get_synced_version : EditorState.t -> int
val get_client_id : EditorState.t -> string

val rebase_updates : Update.t list -> over:Update.t list -> Update.t list
(** [over] only needs each update's changes and client id, which is what
    an authority keeps; a full {!Update.t} carries both. *)
```

Note `receive_updates` returns a `Transaction.t`, which the caller
dispatches: `EditorView.dispatch_transaction`. That is the one place in
the library where a transaction rather than a spec is what you send, so
say so in the doc comment.

## Questions and friction

- `receive_updates` returning a `Transaction.t` read naturally rather than
  fighting the `TransactionSpec`/`Transaction` split: the authority's
  updates aren't a request the caller is making, they're a fact CodeMirror
  has already turned into a transaction (remapped against whatever local,
  unsent edits exist), so handing back a ready `Transaction` — dispatched
  with `EditorView.dispatch_transaction`, not `EditorView.dispatch` —
  follows the split's own logic rather than breaking it; a caller only
  needs telling once, in the doc comment, which side of the pair this is.
- `rebase_updates`'s `over` parameter reuses `Update.t` for a structurally
  smaller JavaScript shape (`{changes, clientID}`, no `effects`, and
  `changes` there is a full `ChangeSet` where the `.d.ts` asks only for a
  `ChangeDesc`); CONVENTIONS.md's "a distinct JavaScript type gets a
  distinct OCaml type" would suggest a fourth type here, but this DESIGN.md
  already called the reuse correct, since an authority's bookkeeping only
  ever holds full `Update.t`s anyway. Worth flagging as a knowing,
  documented exception to that rule rather than a discovered one.
- Otherwise the package produced no friction: no boolean/string unions, no
  forward types, no cross-package identity problem, nothing
  asynchronous. `@codemirror/collab` is exactly the
  small, single-dependency package this file promised, and needing no
  exceptions of its own is itself a small data point that the conventions
  scale down to a seven-export package as well as they scale up.
- Writing the example turned up nothing missing from the bindings:
  `EditorView.dispatch_transaction` (from `Cm_view`, bound earlier) was
  exactly what `receive_updates`'s result needed, and `sendable_updates`,
  `get_synced_version` and `rebase_updates` compose into a working
  authority with no gaps or workarounds.
- The one thing the example clarified, rather than found broken: a local
  edit needs no collab-specific call to become sendable. An ordinary
  `EditorView.dispatch` of a `TransactionSpec` is all `sendable_updates`
  later reports, because the `collab` extension is simply watching every
  transaction that passes through — not obvious from the type signatures
  alone, and worth a sentence for the next reader.
- Running both peers' sync loops off one JS timer in the same page is more
  favorable than a real deployment: a push and a pull can land in the same
  tick, so the example converges faster and more deterministically than
  two processes talking over an actual network ever would. `index.ml`
  says so where the timer is defined, but it is worth restating here since
  it is exactly the kind of thing a reader benchmarking against the demo
  could be misled by.
