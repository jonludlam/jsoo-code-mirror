(* Transactions without a view. A TransactionSpec says what to do; the
   state's EditorState.update does it and returns a Transaction: what
   changed, the effects that ran, and the state that resulted. None of
   this needs an editor on the page, so the results are printed as plain
   text and no code-mirror.view is even linked in. *)

open Brr
open Cm_state

let show lines =
  El.append_children (Document.body G.document)
    [ El.pre (List.map (fun l -> El.txt' (l ^ "\n")) lines) ]

let head st =
  SelectionRange.head (EditorSelection.main (EditorState.selection st))

let initial_doc = "one\ntwo\nthree"
let config = EditorStateConfig.create ~doc:initial_doc ()
let state = EditorState.create ~config ()

(* Insert a line at the end and move the cursor there. *)
let insert =
  let at = String.length initial_doc in
  TransactionSpec.create
    ~changes:(ChangeSpec.insert ~at "\nfour")
    ~selection:(TransactionSpec.Cursor (at + String.length "\nfour"))
    ()

let tr = EditorState.update state [ insert ]
let state' = Transaction.state tr

(* A selection-only spec changes no text. *)
let move = TransactionSpec.create ~selection:(TransactionSpec.Cursor 0) ()
let tr' = EditorState.update state' [ move ]

let () =
  show
    [
      "before:          "
      ^ String.escaped (Text.to_string (EditorState.doc state));
      Printf.sprintf "insert:          doc_changed=%b  doc=%s  cursor=%d"
        (Transaction.doc_changed tr)
        (String.escaped (Text.to_string (EditorState.doc state')))
        (head state');
      Printf.sprintf "move cursor:     doc_changed=%b  doc=%s  cursor=%d"
        (Transaction.doc_changed tr')
        (String.escaped
           (Text.to_string (EditorState.doc (Transaction.state tr'))))
        (head (Transaction.state tr'));
      Printf.sprintf "original state:  doc=%s (states are immutable)"
        (String.escaped (Text.to_string (EditorState.doc state)));
    ]

(* -- self-check -------------------------------------------------------- *)

open Check_core

let () =
  check "inserting text reports doc_changed = true" (fun () ->
      Transaction.doc_changed tr);

  check "a selection-only spec reports doc_changed = false" (fun () ->
      not (Transaction.doc_changed tr'));

  check "the state passed to update is unaffected (states are immutable)"
    (fun () ->
      String.equal (Text.to_string (EditorState.doc state)) initial_doc);

  report ()
