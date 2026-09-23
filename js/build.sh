#!/bin/sh
# js/build.sh ENTRY OUT: bundle one CodeMirror package for the OCaml library
# that binds it. Every other @codemirror/@lezer package is aliased to a shim
# that reads the global the earlier bundle set, so each package is loaded
# once, by the library that owns it. Run from the repository root.
set -e
entry=$1; out=$2
name=$(basename "$entry" .js)
aliases=""
for pkg in state view language commands autocomplete lint search collab; do
  [ "$pkg" = "$name" ] && continue
  aliases="$aliases --alias:@codemirror/$pkg=./js/shims/codemirror-$pkg.js"
done
if [ "$name" != language ]; then
  for l in common highlight lr; do aliases="$aliases --alias:@lezer/$l=./js/shims/lezer-$l.js"; done
fi
node_modules/esbuild/bin/esbuild "$entry" --bundle --format=iife --target=es2017 $aliases --outfile="$out" --log-level=warning
