(* Seed: enough to link a page. To be replaced by the full bindings. *)
let pkg = lazy (Jv.get Jv.global "__CM__view")

module EditorView = struct
  type t = Jv.t
  include (Jv.Id : Jv.CONV with type t := t)
  let create ~state ~parent () =
    let o = Jv.obj [| ("state", Cm_state.EditorState.to_jv state); ("parent", Brr.El.to_jv parent) |] in
    Jv.new' (Jv.get (Lazy.force pkg) "EditorView") [| o |]
  let state (t : t) = Jv.get t "state" |> Cm_state.EditorState.of_jv
end
