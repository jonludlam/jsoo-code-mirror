(* https://codemirror.net/examples/collab/, upstream's worker.ts: the
   authority, run in a web worker. *)

open Brr
open Cm_state
open Cm_collab

(*!authorityState*)

(* The updates received so far (updates.length gives the current
   version) *)
let updates : Update.t list ref = ref []

(* The current document *)
let doc = ref (Text.of_lines [ "Start document" ])

(*!authorityMessage*)

let pending : (Jv.t -> unit) list ref = ref []
let drop n l = List.filteri (fun i _ -> i >= n) l

let to_json us =
  Jv.of_list
    (fun update ->
      Jv.obj
        [|
          ("clientID", Jv.of_string (Update.client_id update));
          ("changes", ChangeSet.to_json (Update.changes update));
        |])
    us

let () =
  Jv.set Jv.global "onmessage"
    (Jv.callback ~arity:1 (fun event ->
         let resp value =
           ignore
             (Jv.call
                (Jv.Jarray.get (Jv.get event "ports") 0)
                "postMessage"
                [| Jv.of_jstr (Json.encode value) |])
         in
         let data =
           Result.get_ok (Json.decode (Jv.to_jstr (Jv.get event "data")))
         in
         let version = Jv.Int.get data "version" in
         (match Jv.to_string (Jv.get data "type") with
         | "pullUpdates" ->
             if version < List.length !updates then
               resp (to_json (drop version !updates))
             else pending := resp :: !pending
         | "pushUpdates" ->
             (* Convert the JSON representation to an actual ChangeSet
                instance *)
             let received =
               Jv.to_list
                 (fun json ->
                   Update.create
                     ~client_id:(Jv.to_string (Jv.get json "clientID"))
                     ~changes:(ChangeSet.of_json (Jv.get json "changes"))
                     ())
                 (Jv.get data "updates")
             in
             let received =
               if version <> List.length !updates then
                 rebase_updates received ~over:(drop version !updates)
               else received
             in
             List.iter
               (fun update ->
                 updates := !updates @ [ update ];
                 doc := ChangeSet.apply (Update.changes update) !doc)
               received;
             resp Jv.true';
             if received <> [] then (
               (* Notify pending requests *)
               let json = to_json received in
               let waiting = !pending in
               pending := [];
               List.iter (fun resp -> resp json) waiting)
         | "getDocument" ->
             resp
               (Jv.obj
                  [|
                    ("version", Jv.of_int (List.length !updates));
                    ("doc", Jv.of_string (Text.to_string !doc));
                  |])
         | _ -> ());
         Jv.undefined))
