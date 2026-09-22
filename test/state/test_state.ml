(* Exercises Cm_state's API under node, without a browser. Only Jv/Jstr are
   used, never Brr. *)
open Cm_state

let failures = ref 0

let check name b =
  if b then Printf.printf "ok %s\n%!" name
  else (
    Printf.printf "FAIL %s\n%!" name;
    incr failures)

(* --- Text --- *)

let text = Text.of_string "line1\nline2\nline3"

let () =
  check "Text.lines" (Text.lines text = 3);
  check "Text.length" (Text.length text = String.length "line1\nline2\nline3");
  check "Text.line" (Line.text (Text.line text 2) = "line2");
  check "Text.line_at" (Line.number (Text.line_at text 6) = 2);
  check "Text.slice" (Text.to_string (Text.slice ~from:6 ~to_:11 text) = "line2");
  check "Text.slice_string" (Text.slice_string ~from:6 ~to_:11 text = "line2");
  check "Text.eq" (Text.eq text (Text.of_lines [ "line1"; "line2"; "line3" ]));
  let buf = Buffer.create 32 in
  Text.iter_lines text (fun l ->
      Buffer.add_string buf l;
      Buffer.add_char buf '|');
  check "Text.iter_lines" (Buffer.contents buf = "line1|line2|line3|");
  let buf2 = Buffer.create 32 in
  Text.iter text (fun s ~line_break:_ -> Buffer.add_string buf2 s);
  check "Text.iter roundtrip" (Buffer.contents buf2 = Text.to_string text);
  let buf3 = Buffer.create 32 in
  Text.iter_range ~from:6 text (fun s ~line_break:_ -> Buffer.add_string buf3 s);
  check "Text.iter_range" (Buffer.contents buf3 = "line2\nline3")

(* --- EditorState.update / Transaction --- *)

let state0 =
  EditorState.create ~config:(EditorStateConfig.create ~doc:"hello" ()) ()

let tr =
  EditorState.update state0
    [ TransactionSpec.create ~changes:(ChangeSpec.insert ~at:5 " world") () ]

let state1 = Transaction.state tr

let () =
  check "Transaction.doc_changed" (Transaction.doc_changed tr);
  check "Transaction.new_doc"
    (Text.to_string (Transaction.new_doc tr) = "hello world");
  check "Transaction.selection unset" (Transaction.selection tr = None);
  check "Transaction.start_state"
    (Text.to_string (EditorState.doc (Transaction.start_state tr)) = "hello");
  check "EditorState.doc after update"
    (Text.to_string (EditorState.doc state1) = "hello world")

(* --- ChangeSet mapping and inversion --- *)

let cs = Transaction.changes tr

let () =
  let inv = ChangeSet.invert cs (EditorState.doc state0) in
  let back = ChangeSet.apply inv (EditorState.doc state1) in
  check "ChangeSet.invert roundtrip" (Text.to_string back = "hello");
  let cs2 = EditorState.changes ~spec:(ChangeSpec.insert ~at:0 ">> ") state1 in
  let composed = ChangeSet.compose cs cs2 in
  check "ChangeSet.compose"
    (Text.to_string (ChangeSet.apply composed (EditorState.doc state0))
    = ">> hello world");
  let cs3 = EditorState.changes ~spec:(ChangeSpec.insert ~at:0 "X") state0 in
  let mapped = ChangeSet.map cs3 (ChangeSet.desc cs) in
  check "ChangeSet.map"
    (Text.to_string (ChangeSet.apply mapped (EditorState.doc state1))
    = "Xhello world")

(* --- StateField + StateEffect --- *)

let effect_ty : int StateEffectType.t = StateEffectType.define Conv.int

let field : int StateField.t =
  StateField.define Conv.int
    ~create:(fun _ -> 0)
    ~update:(fun v tr ->
      List.fold_left
        (fun acc e ->
          match StateEffect.value e effect_ty with Some n -> n | None -> acc)
        v (Transaction.effects tr))

let () =
  let config =
    EditorStateConfig.create ~doc:"x"
      ~extensions:(StateField.extension field)
      ()
  in
  let state2 = EditorState.create ~config () in
  check "StateField initial" (EditorState.field state2 field = 0);
  check "StateField.field_opt Some" (EditorState.field_opt state2 field = Some 0);
  let tr2 =
    EditorState.update state2
      [
        TransactionSpec.create ~effects:[ StateEffectType.of_ effect_ty 42 ] ();
      ]
  in
  let state3 = Transaction.state tr2 in
  check "StateField after effect" (EditorState.field state3 field = 42);
  check "StateField.field_opt on other state"
    (EditorState.field_opt state0 field = None)

(* --- Facet.define with combine --- *)

let my_facet : (int, int) Facet.t =
  Facet.define ~combine:(List.fold_left ( + ) 0) Conv.int Conv.int

let () =
  let config =
    EditorStateConfig.create
      ~extensions:
        (Extension.of_list [ Facet.of_ my_facet 3; Facet.of_ my_facet 4 ])
      ()
  in
  let state4 = EditorState.create ~config () in
  check "Facet.combine" (EditorState.facet state4 my_facet = 7)

(* --- Compartment.reconfigure --- *)

let compartment = Compartment.make ()

let () =
  let config =
    EditorStateConfig.create
      ~extensions:(Compartment.of_ compartment (Facet.of_ my_facet 10))
      ()
  in
  let state5 = EditorState.create ~config () in
  check "Compartment initial" (EditorState.facet state5 my_facet = 10);
  let tr3 =
    EditorState.update state5
      [
        TransactionSpec.create
          ~effects:
            [ Compartment.reconfigure compartment (Facet.of_ my_facet 99) ]
          ();
      ]
  in
  let state6 = Transaction.state tr3 in
  check "Compartment.reconfigure" (EditorState.facet state6 my_facet = 99);
  check "Transaction.reconfigured" (Transaction.reconfigured tr3);
  check "Compartment.get" (Option.is_some (Compartment.get compartment state6))

(* --- RangeSet / RangeSetBuilder / Range, using a Decoration as the
   RangeValue (see test/state/dune: this test depends on code-mirror.view
   for exactly this; a RangeValue has no public constructor to subclass
   from OCaml). --- *)

let deco_conv : Jv.t Conv.t = Conv.jv

let mark_decoration () =
  let cm_view = Jv.get Jv.global "__CM__view" in
  let decoration_cls = Jv.get cm_view "Decoration" in
  Jv.call decoration_cls "mark" [| Jv.obj [||] |]

let () =
  let r1 = Range.make deco_conv ~from:0 ~to_:3 (mark_decoration ()) in
  let r2 = Range.make deco_conv ~from:5 ~to_:8 (mark_decoration ()) in
  check "Range.from/to_" (Range.from r1 = 0 && Range.to_ r2 = 8);
  let rs = RangeSet.of_ deco_conv [ r1; r2 ] in
  check "RangeSet.size" (RangeSet.size rs = 2);
  let count = ref 0 in
  RangeSet.iter rs (fun _ -> incr count);
  check "RangeSet.iter" (!count = 2);
  let touched = ref 0 in
  RangeSet.between ~from:0 ~to_:4 rs (fun ~from:_ ~to_:_ _ ->
      incr touched;
      true);
  check "RangeSet.between" (!touched = 1);
  check "RangeSet.eq reflexive" (RangeSet.eq rs rs);
  let builder = RangeSetBuilder.make deco_conv () in
  RangeSetBuilder.add builder ~from:0 ~to_:2 (mark_decoration ());
  RangeSetBuilder.add builder ~from:4 ~to_:6 (mark_decoration ());
  let rs2 = RangeSetBuilder.finish builder in
  check "RangeSetBuilder.finish" (RangeSet.size rs2 = 2);
  let rs3 =
    RangeSet.update
      ~add:[ Range.make deco_conv ~from:10 ~to_:12 (mark_decoration ()) ]
      rs
  in
  check "RangeSet.update add" (RangeSet.size rs3 = 3);
  let rs4 = RangeSet.update ~filter:(fun ~from ~to_:_ _ -> from <> 0) rs3 in
  check "RangeSet.update filter" (RangeSet.size rs4 = 2);
  (* [cs] is a changeset over "hello" (length 5); map a range set defined
     against that same document. *)
  let rs_small =
    RangeSet.of_ deco_conv
      [ Range.make deco_conv ~from:1 ~to_:3 (mark_decoration ()) ]
  in
  let mapped = RangeSet.map rs_small (ChangeSet.desc cs) in
  check "RangeSet.map" (RangeSet.size mapped = 1)

(* --- Annotations --- *)

let my_annotation : string AnnotationType.t = AnnotationType.define Conv.string

let () =
  let tr4 =
    EditorState.update state0
      [
        TransactionSpec.create
          ~annotations:[ AnnotationType.of_ my_annotation "hi" ]
          ();
      ]
  in
  check "Transaction.annotation"
    (Transaction.annotation tr4 my_annotation = Some "hi");
  check "Transaction.annotation absent"
    (Transaction.annotation tr4 Transaction.remote = None);
  check "Transaction.time"
    (Option.is_some (Transaction.annotation tr4 Transaction.time));
  let tr5 =
    EditorState.update state0
      [ TransactionSpec.create ~user_event:"input.type" () ]
  in
  check "Transaction.is_user_event exact"
    (Transaction.is_user_event tr5 "input.type");
  check "Transaction.is_user_event prefix"
    (Transaction.is_user_event tr5 "input");
  check "Transaction.is_user_event mismatch"
    (not (Transaction.is_user_event tr5 "delete"));
  let tr6 =
    EditorState.update state0
      [ TransactionSpec.create ~selection:(TransactionSpec.Cursor 3) () ]
  in
  match Transaction.selection tr6 with
  | Some sel ->
      check "TransactionSpec.Cursor"
        (SelectionRange.from (EditorSelection.main sel) = 3)
  | None -> check "TransactionSpec.Cursor" false

(* --- Prec --- *)

let () =
  let config =
    EditorStateConfig.create
      ~extensions:
        (Extension.of_list
           [
             Prec.highest (Facet.of_ my_facet 1);
             Prec.lowest (Facet.of_ my_facet 2);
           ])
      ()
  in
  let state7 = EditorState.create ~config () in
  check "Prec-wrapped extension still combines"
    (EditorState.facet state7 my_facet = 3)

(* --- EditorState.change_by_range --- *)

let () =
  let _changes, sel, _effects =
    EditorState.change_by_range state0 (fun r ->
        {
          range =
            SelectionRange.extend r ~from:(SelectionRange.from r)
              ~to_:(SelectionRange.from r + 2)
              ();
          changes = None;
          effects = [];
        })
  in
  check "EditorState.change_by_range"
    (SelectionRange.to_ (EditorSelection.main sel) = 2)

(* --- count_column / find_column and friends --- *)

let () =
  check "count_column" (count_column "\ta" ~tab_size:4 () = 5);
  check "find_column tab" (find_column "\ta" ~col:4 ~tab_size:4 () = 1);
  check "find_column plain" (find_column "ab" ~col:1 ~tab_size:4 () = 1);
  let emoji = "\xF0\x9F\x98\x80x" in
  check "find_cluster_break" (find_cluster_break emoji 0 = 2);
  let cp = code_point_at emoji 0 in
  check "code_point_at" (cp = 128512);
  check "code_point_size" (code_point_size cp = 2);
  check "from_code_point" (from_code_point cp = String.sub emoji 0 4)

let () =
  if !failures > 0 then (
    Printf.printf "%d failure(s)\n%!" !failures;
    exit 1)
  else Printf.printf "all ok\n%!"
