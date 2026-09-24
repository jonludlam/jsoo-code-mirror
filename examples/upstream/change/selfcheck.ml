open Example_check

let () =
  check "all four changes applied, in order" (fun () ->
      text Change.view
      = "★__#!/usr/bin/env node\n  console.log(\"hello\")\n  return tabs");
  report ()
