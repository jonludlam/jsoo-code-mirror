open Cm_state

let pkg = lazy (Jv.get Jv.global "__CM__collab")

module Update = struct
  type t = Jv.t

  include (Jv.Id : Jv.CONV with type t := t)

  let conv = Conv.{ to_jv; of_jv }

  let create ?effects ~changes ~client_id () : t =
    let o = Jv.obj [||] in
    Jv.set o "changes" (ChangeSet.to_jv changes);
    (match effects with
    | None -> ()
    | Some l -> Jv.set o "effects" (Jv.of_list StateEffect.to_jv l));
    Jv.set o "clientID" (Jv.of_string client_id);
    o

  let changes t = ChangeSet.of_jv (Jv.get t "changes")

  let effects t =
    match Jv.find t "effects" with
    | None -> []
    | Some v -> Jv.to_list StateEffect.of_jv v

  let client_id t = Jv.to_string (Jv.get t "clientID")
  let origin t = Jv.find t "origin" |> Option.map Transaction.of_jv
end

let collab ?start_version ?client_id ?shared_effects () : Extension.t =
  let o = Jv.obj [||] in
  Jv.Int.set_if_some o "startVersion" start_version;
  Jv.set_if_some o "clientID" (Option.map Jv.of_string client_id);
  Option.iter
    (fun f ->
      Jv.set o "sharedEffects"
        (Jv.callback ~arity:1 (fun (tr : Jv.t) ->
             Jv.of_list StateEffect.to_jv (f (Transaction.of_jv tr)))))
    shared_effects;
  Extension.of_jv (Jv.call (Lazy.force pkg) "collab" [| o |])

let receive_updates (state : EditorState.t) (updates : Update.t list) :
    Transaction.t =
  Jv.call (Lazy.force pkg) "receiveUpdates"
    [| EditorState.to_jv state; Jv.of_list Update.to_jv updates |]
  |> Transaction.of_jv

let sendable_updates (state : EditorState.t) : Update.t list =
  Jv.call (Lazy.force pkg) "sendableUpdates" [| EditorState.to_jv state |]
  |> Jv.to_list Update.of_jv

let get_synced_version (state : EditorState.t) : int =
  Jv.call (Lazy.force pkg) "getSyncedVersion" [| EditorState.to_jv state |]
  |> Jv.to_int

let get_client_id (state : EditorState.t) : string =
  Jv.call (Lazy.force pkg) "getClientID" [| EditorState.to_jv state |]
  |> Jv.to_string

let rebase_updates (updates : Update.t list) ~(over : Update.t list) :
    Update.t list =
  Jv.call (Lazy.force pkg) "rebaseUpdates"
    [| Jv.of_list Update.to_jv updates; Jv.of_list Update.to_jv over |]
  |> Jv.to_list Update.of_jv
