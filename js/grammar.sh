#!/bin/sh
# js/grammar.sh GRAMMAR GLOBAL: what js/build.sh does for a package, for a
# Lezer grammar of your own. lezer-generator writes parser.js beside the
# grammar (the module a JavaScript project would import), and esbuild
# bundles that for js_of_ocaml as parser.bundle.js, setting GLOBAL to the
# module's exports. @lezer packages are aliased to the shims, so the parser
# uses the ones the language library already loaded. Run from the
# repository root.
set -e
grammar=$1; global=$2
dir=$(dirname "$grammar")
node node_modules/@lezer/generator/src/lezer-generator.cjs --noTerms --output "$dir/parser.js" "$grammar"
aliases=""
for l in common highlight lr; do aliases="$aliases --alias:@lezer/$l=./js/shims/lezer-$l.js"; done
node_modules/esbuild/bin/esbuild "$dir/parser.js" --bundle --format=iife --target=es2017 \
  --global-name=__grammar --footer:js="globalThis.$global = __grammar;" \
  $aliases --outfile="$dir/parser.bundle.js" --log-level=warning
