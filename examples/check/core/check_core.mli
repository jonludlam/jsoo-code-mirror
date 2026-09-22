(** What every example's self-check shares, needing no editor: [check] records a
    named result, and [report] publishes them as [window.exampleResults].
    {!Example_check} adds what drives and reads an editor. *)

val check : string -> (unit -> bool) -> unit

val note : string -> bool -> unit
(** Records a result already known, such as one a future delivered. *)

val on_report : (unit -> unit) -> unit
(** [on_report f] runs [f] when {!report} is called, before the results are
    published. *)

val report : unit -> unit

val wait_for : ?ms:int -> tries:int -> (unit -> bool) -> bool Fut.t
(** Polls every [ms] (default 50) until the predicate holds, or [tries] run out.
*)

val after : int -> (unit -> unit) -> unit
(** [after ms f] runs [f] later, for checks that wait on CodeMirror's measure
    cycle or a timer. *)

val contains : sub:string -> string -> bool
