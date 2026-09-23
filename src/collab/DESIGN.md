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
