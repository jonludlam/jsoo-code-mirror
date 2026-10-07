# How the JavaScript side works

The OCaml bindings call into CodeMirror, which is JavaScript. This folder
holds what turns CodeMirror into files a web page can load. This note
explains how that works, assuming no knowledge of JavaScript packaging.

## Packages

JavaScript code is shared as *packages*. CodeMirror is not one big thing
but a set of packages, each with one job:

- `@codemirror/state`: the document and its history, with no drawing
- `@codemirror/view`: draws the editor on the page
- `@codemirror/language`: syntax highlighting, folding, indentation
- `@codemirror/commands`: editing commands and the default key bindings
- `@codemirror/autocomplete`, `@codemirror/lint`, `@codemirror/search`
- `@codemirror/legacy-modes`: older language modes (we use OCaml's)
- `@codemirror/theme-one-dark`: a dark theme

`package.json` lists the packages we use. `npm install` downloads them
into `node_modules/`, and `package-lock.json` records the exact version
of each, so everyone gets the same code.

## Packages use each other

A file in one package can use another package:

```js
import { EditorState } from "@codemirror/state";
```

means "I need `EditorState`, which lives in the state package". Lint
uses state and view, view uses state, and so on.

## Bundles

A web page has no `node_modules/`, so it cannot find `@codemirror/state`
by name. The code has to be gathered up ahead of time by a *bundler*; we
use [esbuild](https://esbuild.github.io/). Given a starting file, it
follows every `import`, pulls in the code each one points to, and writes
it all out as one file a browser can run: a *bundle*.

Each package has a small starting file in `entries/`. The one for lint
is:

```js
import * as m from "@codemirror/lint";
globalThis.__CM__lint = m;
```

The first line brings in everything the lint package offers, as `m`. The
second puts it on `globalThis`, an object every script on the page can
see, under the name `__CM__lint`. That is how OCaml reaches it:

```ocaml
Jv.get Jv.global "__CM__lint"
```

Everything else in a bundle stays private: the bundle is one function
that runs straight away (an *IIFE*) and leaves behind only the name its
entry sets. Each package's name is `__CM__` followed by the package name,
with `-` written as `_`.

## One copy of each package

If lint were bundled the simple way, its bundle would contain a copy of
state, since lint uses state. So would view's, and every other bundle's.

Two copies of state on one page break CodeMirror. It often checks
whether a value is, say, an `EditorState`, and the check means "was it
made by *my* `EditorState`?". A value made by one copy fails the check
in the other, and CodeMirror rejects it. Each package must be on the
page exactly once.

The fix is the *shims* in `shims/`. The one for state is a single line:

```js
module.exports = globalThis.__CM__state;
```

It stands in for the state package: "I am whatever is already on the
page as `__CM__state`". `build.sh` tells esbuild, through its `--alias`
flags, to use the shim whenever anything asks for `@codemirror/state`.
So lint's bundle holds only lint, and borrows state and view from the
page.

Every bundle is built this way: its own package for real, every other
CodeMirror package through a shim. The lezer packages, the parsing tools
CodeMirror is built on, belong to the language bundle, which sets
`__CM__lezer_common`, `__CM__lezer_highlight` and `__CM__lezer_lr` for
the others to borrow.

## Order

A shim reads `globalThis` when its bundle runs. If lint's bundle ran
before state's, there would be nothing to read yet.

dune keeps the order right. Each package has an OCaml library in
`src/`, and the library carries the bundle:

```
(js_of_ocaml (javascript_files bundle.js))
```

When js_of_ocaml builds a page, it puts in the bundle of every library
the page uses, dependencies first, then the OCaml code. `cm_lint`
depends on `cm_state` and `cm_view`, so their bundles come before lint's.
So a library's `libraries` field must list every package its bundle
borrows.

A page that uses lint ends up as:

```
state bundle   sets __CM__state
view bundle    borrows state; sets __CM__view
lint bundle    borrows state and view; sets __CM__lint
OCaml code     reads them
```

A page only gets the bundles of the libraries it depends on, and the
libraries those depend on: depending on `code-mirror.lint` gets state,
view and lint; depending on `code-mirror.state` alone gets only state.
There is no library that brings in everything.

| npm package                  | library                      | OCaml module        |
|------------------------------|------------------------------|---------------------|
| `@codemirror/state`          | `code-mirror.state`          | `Cm_state`          |
| `@codemirror/view`           | `code-mirror.view`           | `Cm_view`           |
| `@codemirror/language`       | `code-mirror.language`       | `Cm_language`       |
| `@codemirror/commands`       | `code-mirror.commands`       | `Cm_commands`       |
| `@codemirror/autocomplete`   | `code-mirror.autocomplete`   | `Cm_autocomplete`   |
| `@codemirror/lint`           | `code-mirror.lint`           | `Cm_lint`           |
| `@codemirror/search`         | `code-mirror.search`         | `Cm_search`         |
| `@codemirror/legacy-modes`   | `code-mirror.legacy-modes`   | `Cm_legacy_modes`   |
| `@codemirror/theme-one-dark` | `code-mirror.theme-one-dark` | `Cm_theme_one_dark` |
| `codemirror`                 | `code-mirror`                | `Code_mirror`       |

## basicSetup has no bundle

The `codemirror` package is only two lists, `basicSetup` and
`minimalSetup`: "line numbers, undo history, bracket matching, ...",
each item from another package. It has no code of its own, so it is not
bundled. `code-mirror` (`src/codemirror/code_mirror.ml`) builds the
same lists in OCaml, as `basic_setup` and `minimal_setup`, taking each
item from the package that provides it, and depends on those seven
packages so their bundles are on the page. If a new release of
`codemirror` changes the lists, that file has to be updated by hand.

## Making the bundles

Making a bundle needs node and `npm install`, which users of the OCaml
library should not need. So the bundles are made once and committed, as
`src/*/bundle.js`; normal builds just use them.

To make them again, for example after updating a CodeMirror version in
`package.json`:

```
npm install
dune build --profile=with-bundle
```

(`make bundle` does both.) Each library's `dune` has a rule that, in that
profile only, runs `sh js/build.sh js/entries/<name>.js bundle.js` and
copies the result back into `src/`.

The bundles are written as ES2017, a version of JavaScript every current
browser understands, and are left readable. js_of_ocaml compacts them
in release builds.

## Adding a package

To bind another CodeMirror package, say `@codemirror/lang-markdown`:

1. `npm install @codemirror/lang-markdown`, which adds it to
   `package.json`.
2. Add `entries/lang_markdown.js`, setting `globalThis.__CM__lang_markdown`.
3. Add `src/lang_markdown/` with a `dune` file like the others: library
   `cm_lang_markdown`, public name `code-mirror.lang-markdown`, and in
   `libraries` every package it imports.
4. If other bundles will import the new package, add a shim for it in
   `shims/` and add it to the list in `build.sh`. Without one, any bundle
   that imports it gets its own copy.
5. Make the bundles, as above.

A package the new one imports that has no shim is bundled inside the new
one. That is fine as long as nothing else on the page uses it too.
