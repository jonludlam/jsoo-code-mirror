jsoo-code-mirror
----------------

Bindings using [brr](https://erratique.ch/software/brr) to [code-mirror
6](https://codemirror.net/6/).

There is one library per CodeMirror package (`code-mirror.state`,
`code-mirror.view`, `code-mirror.lint`, ...), each carrying that
package's JavaScript, and `code-mirror`, which brings them all together.
Depend on the libraries a page uses to keep it small. How the JavaScript
is bundled, and how to add a package, is explained in
[js/README.md](js/README.md).
