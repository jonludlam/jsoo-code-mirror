(* Seed: enough to link a page. To be replaced by the full bindings. *)
let pkg = lazy (Jv.get Jv.global "__CM__state")

module Text = struct
  type t = Jv.t
  include (Jv.Id : Jv.CONV with type t := t)
  let to_string (t : t) = Jv.to_string (Jv.call t "toString" [||])
end

module EditorState = struct
  type t = Jv.t
  include (Jv.Id : Jv.CONV with type t := t)
  let create ?doc () =
    let o = Jv.obj [||] in
    Jv.Jstr.set_if_some o "doc" (Option.map Jstr.v doc);
    Jv.call (Jv.get (Lazy.force pkg) "EditorState") "create" [| o |]
  let doc (t : t) = Jv.get t "doc" |> Text.of_jv
end
