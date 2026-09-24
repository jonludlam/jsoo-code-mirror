(* https://codemirror.net/examples/decoration/, its third editor *)

open Brr
open Cm_view

(*!placeholderWidget*)

(* Upstream defines the widget after the matcher that uses it; OCaml needs
   it first. *)
let placeholder_widget =
  WidgetType.define
    ~eq:(fun name other -> name = other)
    ~to_dom:(fun name _ ->
      let elt = El.span [ El.txt' name ] in
      El.set_at (Jstr.v "style")
        (Some
           (Jstr.v
              "\n\
              \      border: 1px solid blue;\n\
              \      border-radius: 4px;\n\
              \      padding: 0 3px;\n\
              \      background: lightblue;"))
        elt;
      elt)
    ~ignore_event:(fun _ _ -> false)
    ()

(*!placeholderMatcher*)

let placeholder_matcher =
  MatchDecorator.create
    ~regexp:
      (Jv.new'
         (Jv.get Jv.global "RegExp")
         [| Jv.of_string {|\[\[(\w+)\]\]|}; Jv.of_string "g" |])
    ~decoration:
      (`Of_match
         (fun match_ _ _ ->
           Some (Decoration.replace ~widget:(placeholder_widget match_.(1)) ())))
    ()

(*!placeholderPlugin*)

type placeholders = { mutable placeholders : Decoration.t Cm_state.RangeSet.t }

let placeholders =
  ViewPlugin.define
    ~update:(fun this update ->
      this.placeholders <-
        MatchDecorator.update_deco placeholder_matcher update this.placeholders)
    ~decorations:(fun instance -> instance.placeholders)
    ~provide:(fun plugin ->
      Cm_state.Facet.of_ EditorView.atomic_ranges (fun view ->
          match EditorView.plugin view plugin with
          | Some p -> p.placeholders
          | None -> Decoration.none))
    (fun view ->
      { placeholders = MatchDecorator.create_deco placeholder_matcher view })

(*!placeholderCreate*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create
         ~doc:
           "Dear [[name]],\n\
            Your [[item]] is on its way. Please see [[order]] for details.\n"
         ~extensions:
           (Cm_state.Extension.of_list
              [ ViewPlugin.extension placeholders; Code_mirror.minimal_setup ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor-placeholder")))
         ())
    ()
