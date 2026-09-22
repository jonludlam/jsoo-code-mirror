(* Transactions without a view. A TransactionSpec says what to do; the
   state's [update] does it and returns a Transaction: what changed, the
   effects that ran, and the state that resulted. None of this needs an
   editor on the page, so the results are printed as plain text. *)

open Code_mirror
open Brr

let show lines =
  El.append_children (Document.body G.document)
    [ El.pre (List.map (fun l -> El.txt' (l ^ "\n")) lines) ]

let doc_of state =
  String.concat "\n"
    (Array.to_list
       (Array.map Jstr.to_string
          (State.Text.to_jstr_array (State.EditorState.doc state))))

let () =
  let config = State.EditorStateConfig.create ~doc:"one\ntwo\nthree" () in
  let state = State.EditorState.create ~config () in
  (* Insert a line at the end and move the cursor there. *)
  let insert =
    State.TransactionSpec.create
      ~changes:
        {
          from = String.length "one\ntwo\nthree";
          to_ = None;
          insert = Some "\nfour";
        }
      ~selection:
        (State.TransactionSpec.Short
           { anchor = String.length "one\ntwo\nthree\nfour"; head = None })
      ()
  in
  let tr = State.EditorState.update state [ insert ] in
  let state' = State.Transaction.state tr in
  (* A selection-only spec changes no text. *)
  let move =
    State.TransactionSpec.create
      ~selection:(State.TransactionSpec.Short { anchor = 0; head = None })
      ()
  in
  let tr' = State.EditorState.update state' [ move ] in
  let head st =
    State.SelectionRange.head
      (List.hd (State.EditorSelection.ranges (State.EditorState.selection st)))
  in
  show
    [
      "before:          " ^ String.escaped (doc_of state);
      Printf.sprintf "insert:          doc_changed=%b  doc=%s  cursor=%d"
        (State.Transaction.doc_changed tr)
        (String.escaped (doc_of state'))
        (head state');
      Printf.sprintf "move cursor:     doc_changed=%b  doc=%s  cursor=%d"
        (State.Transaction.doc_changed tr')
        (String.escaped (doc_of (State.Transaction.state tr')))
        (head (State.Transaction.state tr'));
      Printf.sprintf "original state:  doc=%s (states are immutable)"
        (String.escaped (doc_of state));
    ]
