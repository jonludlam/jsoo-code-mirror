#!/bin/sh
# js/build.sh ENTRY OUT: bundle one CodeMirror package for the OCaml library
# that binds it. Every other @codemirror/@lezer package is aliased to a shim
# that reads the global the earlier bundle set, so each package is loaded
# once, by the library that owns it. Run from the repository root.
set -e
entry=$1; out=$2
name=$(basename "$entry" .js | tr _ -)
aliases=""
for pkg in state view language commands autocomplete lint search collab \
           lang-css lang-javascript lang-html lang-python; do
  [ "$pkg" = "$name" ] && continue
  aliases="$aliases --alias:@codemirror/$pkg=./js/shims/codemirror-$pkg.js"
done
if [ "$name" != language ]; then
  for l in common highlight lr; do aliases="$aliases --alias:@lezer/$l=./js/shims/lezer-$l.js"; done
fi
# A language package's Lezer parser is bundled with it, and read from
# there by any package that imports it.
for l in css javascript html python; do
  [ "$name" = "lang-$l" ] && continue
  aliases="$aliases --alias:@lezer/$l=./js/shims/lezer-$l.js"
done
node_modules/esbuild/bin/esbuild "$entry" --bundle --format=iife --target=es2017 $aliases --outfile="$out" --log-level=warning
