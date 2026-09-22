open Brr
open Cm_state
open Cm_view
include Check_core

(* The views a check will change, with the states to put back. *)
let kept = ref []

let () =
  on_report (fun () ->
      List.iter (fun (v, state) -> EditorView.set_state v state) !kept)

let keep views =
  kept := List.map (fun v -> (v, EditorView.state v)) views @ !kept

let text view = Text.to_string (EditorState.doc (EditorView.state view))

(* What a browser sends: a letter comes with its keyCode, and in upper
   case when Shift is held. CodeMirror uses the keyCode to find bindings
   such as Shift-Mod-h. *)
let press ?(shift = false) ?(ctrl = false) ?(meta = false) view key =
  let letter =
    String.length key = 1
    && Char.lowercase_ascii key.[0] <> Char.uppercase_ascii key.[0]
  in
  let key = if letter && shift then String.uppercase_ascii key else key in
  let key_code =
    if letter then Char.code (Char.uppercase_ascii key.[0]) else 0
  in
  let init =
    Jv.obj
      [|
        ("key", Jv.of_string key);
        ("keyCode", Jv.of_int key_code);
        ("shiftKey", Jv.of_bool shift);
        ("ctrlKey", Jv.of_bool ctrl);
        ("metaKey", Jv.of_bool meta);
        ("cancelable", Jv.true');
        ("bubbles", Jv.true');
      |]
  in
  let ev =
    Jv.new'
      (Jv.get Jv.global "KeyboardEvent")
      [| Jv.of_string "keydown"; init |]
  in
  Ev.dispatch (Ev.of_jv ev) (El.as_target (EditorView.content_dom view))

(* CodeMirror's "Mod": Cmd on a Mac, Ctrl elsewhere. *)
let mac =
  contains ~sub:"Mac"
    (Jstr.to_string
       (Jv.to_jstr (Jv.get (Jv.get Jv.global "navigator") "platform")))

let press_mod ?shift view key =
  if mac then press ?shift ~meta:true view key
  else press ?shift ~ctrl:true view key

let select view from to_ =
  EditorView.dispatch view
    (TransactionSpec.create
       ~selection:(TransactionSpec.Anchor_head { anchor = from; head = to_ })
       ())

let by_class view cls =
  El.find_by_class ~root:(EditorView.dom view) (Jstr.v cls)

let texts els = List.map (fun el -> Jstr.to_string (El.text_content el)) els
