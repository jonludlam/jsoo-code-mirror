jsoo-code-mirror
----------------

Bindings using [brr](https://erratique.ch/software/brr) to [code-mirror
6](https://codemirror.net/6/).

There is one library per CodeMirror package (`code-mirror.state`,
`code-mirror.view`, `code-mirror.lint`, ...), each carrying that
package's JavaScript; `code-mirror` itself is the `codemirror` package,
`basic_setup` and `minimal_setup`. A page depends on the libraries it
uses, and gets only their JavaScript. The examples show how. How the
JavaScript is bundled, and how to add a package, is explained in
[js/README.md](js/README.md).
