(** {!Check_core}, with {!keep}, which has {!Check_core.report} put the views a
    check changed back as they were, and helpers that drive and read an editor.
*)

open Cm_view

include module type of struct
  include Check_core
end

val keep : EditorView.t list -> unit
(** [keep views], before a check changes them, has {!report} put each back as it
    was, so the page opens as it did. *)

val text : EditorView.t -> string

val press :
  ?shift:bool -> ?ctrl:bool -> ?meta:bool -> EditorView.t -> string -> bool
(** Sends a keydown to the view's content; [false] if a handler took it. *)

val press_mod : ?shift:bool -> EditorView.t -> string -> bool
(** As {!press} with CodeMirror's [Mod]: Cmd on a Mac, Ctrl elsewhere. *)

val select : EditorView.t -> int -> int -> unit
val by_class : EditorView.t -> string -> Brr.El.t list
val texts : Brr.El.t list -> string list
