open Brr

let details = ref []
let check name f = details := (name, try f () with _ -> false) :: !details
let note name ok = details := (name, ok) :: !details

(* Run before the results are published, in the order registered. *)
let before = ref []
let on_report f = before := !before @ [ f ]

let report () =
  List.iter (fun f -> f ()) !before;
  let details = List.rev !details in
  let total = List.length details in
  let passed = List.length (List.filter (fun (_, ok) -> ok) details) in
  let pair (name, ok) =
    Jv.obj [| ("name", Jv.of_string name); ("ok", Jv.of_bool ok) |]
  in
  Jv.set Jv.global "exampleResults"
    (Jv.obj
       [|
         ("total", Jv.of_int total);
         ("passed", Jv.of_int passed);
         ("failed", Jv.of_int (total - passed));
         ("details", Jv.of_list pair details);
         ("done", Jv.true');
       |])

let after ms f = ignore (G.set_timeout ~ms f)

let rec wait_for ?(ms = 50) ~tries pred =
  if pred () then Fut.return true
  else if tries <= 0 then Fut.return false
  else Fut.bind (Fut.tick ~ms) (fun () -> wait_for ~ms ~tries:(tries - 1) pred)

let contains ~sub s = Jstr.find_sub ~sub:(Jstr.v sub) (Jstr.v s) <> None
