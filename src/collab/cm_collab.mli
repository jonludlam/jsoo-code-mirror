(** {{:https://codemirror.net/docs/ref/#collab} \@codemirror/collab}:
    operational-transform collaborative editing against a central authority. *)

open Cm_state

(** {{:https://codemirror.net/docs/ref/#collab.Update} collab.Update}: one
    client's changes, as the authority passes them around. *)
module Update : sig
  type t

  include Jv.CONV with type t := t

  val conv : t Conv.t

  val create :
    ?effects:StateEffect.t list ->
    changes:ChangeSet.t ->
    client_id:string ->
    unit ->
    t

  val changes : t -> ChangeSet.t
  val effects : t -> StateEffect.t list
  val client_id : t -> string

  val origin : t -> Transaction.t option
  (** Only on the updates {!sendable_updates} returns: the transaction that made
      this update, before any remapping. *)
end

val collab :
  ?start_version:int ->
  ?client_id:string ->
  ?shared_effects:(Transaction.t -> StateEffect.t list) ->
  unit ->
  Extension.t
(** {{:https://codemirror.net/docs/ref/#collab.collab} collab.collab} *)

val receive_updates : EditorState.t -> Update.t list -> Transaction.t
(** {{:https://codemirror.net/docs/ref/#collab.receiveUpdates}
     collab.receiveUpdates}: a transaction that moves the state forward to the
    authority's view of the document, built from updates received from it.
    Unlike everywhere else in this library, this is a {!Transaction.t} rather
    than a {!TransactionSpec.t}: dispatch it directly with
    {!Cm_view.EditorView.dispatch_transaction} rather than
    {!Cm_view.EditorView.dispatch}. *)

val sendable_updates : EditorState.t -> Update.t list
(** {{:https://codemirror.net/docs/ref/#collab.sendableUpdates}
     collab.sendableUpdates}: the locally made updates still to be sent to the
    authority. Each one's {!Update.origin} is set. *)

val get_synced_version : EditorState.t -> int
(** {{:https://codemirror.net/docs/ref/#collab.getSyncedVersion}
     collab.getSyncedVersion} *)

val get_client_id : EditorState.t -> string
(** {{:https://codemirror.net/docs/ref/#collab.getClientID} collab.getClientID}
*)

val rebase_updates : Update.t list -> over:Update.t list -> Update.t list
(** {{:https://codemirror.net/docs/ref/#collab.rebaseUpdates}
     collab.rebaseUpdates}. [over] only needs each update's changes and client
    id, which is what an authority keeps; a full {!Update.t} carries both. *)
