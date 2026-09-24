(* https://codemirror.net/examples/autocompletion/, its third editor *)

open Brr
open Cm_state
open Cm_view
open Cm_autocomplete

(*!completeJSDoc*)

let tag_options =
  List.map
    (fun tag -> Completion.create ~label:("@" ^ tag) ~type_:"keyword" ())
    [ "constructor"; "deprecated"; "link"; "param"; "returns"; "type" ]

(* JavaScript's [/@\w*$/.exec(text)]: where a trailing [@word] starts. *)
let tag_before text =
  let is_word c =
    (c >= 'a' && c <= 'z')
    || (c >= 'A' && c <= 'Z')
    || (c >= '0' && c <= '9')
    || c = '_'
  in
  let i = ref (String.length text) in
  while !i > 0 && is_word text.[!i - 1] do
    decr i
  done;
  if !i > 0 && text.[!i - 1] = '@' then Some (!i - 1) else None

let complete_js_doc context =
  let state = CompletionContext.state context
  and pos = CompletionContext.pos context in
  let node_before =
    Cm_language.Tree.resolve_inner
      (Cm_language.syntax_tree state)
      pos ~side:(-1)
  in
  let from = Cm_language.SyntaxNode.from node_before in
  if
    Cm_language.SyntaxNode.name node_before <> "BlockComment"
    || EditorState.slice_doc ~from ~to_:(from + 3) state <> "/**"
  then Fut.return None
  else
    let text_before = EditorState.slice_doc ~from ~to_:pos state in
    let tag_before = tag_before text_before in
    if tag_before = None && not (CompletionContext.explicit context) then
      Fut.return None
    else
      Fut.return
        (Some
           (CompletionResult.create
              ~from:
                (match tag_before with
                | Some index -> from + index
                | None -> pos)
              ~options:tag_options
              ~valid_for:
                (`Regexp
                   (Jv.new'
                      (Jv.get Jv.global "RegExp")
                      [| Jv.of_string {|^(@\w*)?$|} |]))
              ()))

(*!jsDocCompletions*)

let js_doc_completions =
  Facet.of_
    (Cm_language.Language.data
       (Cm_language.LRLanguage.to_language
          Cm_lang_javascript.javascript_language))
    (Jv.obj
       [| ("autocomplete", completion_source_conv.to_jv complete_js_doc) |])

(*!createJavaScriptEditor*)

let view =
  EditorView.create
    ~config:
      (EditorViewConfig.create ~doc:"/** Complete tags here\n    @pa\n */\n"
         ~extensions:
           (Extension.of_list
              [
                Code_mirror.basic_setup;
                Cm_language.Language.extension
                  (Cm_language.LRLanguage.to_language
                     Cm_lang_javascript.javascript_language);
                js_doc_completions;
                autocompletion ();
              ])
         ~parent:
           (Option.value ~default:(Document.body G.document)
              (Document.find_el_by_id G.document (Jstr.v "editor-javascript")))
         ())
    ()
