(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));

  // js/shims/codemirror-view.js
  var require_codemirror_view = __commonJS({
    "js/shims/codemirror-view.js"(exports, module) {
      module.exports = globalThis.__CM__view;
    }
  });

  // js/shims/codemirror-state.js
  var require_codemirror_state = __commonJS({
    "js/shims/codemirror-state.js"(exports, module) {
      module.exports = globalThis.__CM__state;
    }
  });

  // js/shims/codemirror-language.js
  var require_codemirror_language = __commonJS({
    "js/shims/codemirror-language.js"(exports, module) {
      module.exports = globalThis.__CM__language;
    }
  });

  // js/shims/codemirror-commands.js
  var require_codemirror_commands = __commonJS({
    "js/shims/codemirror-commands.js"(exports, module) {
      module.exports = globalThis.__CM__commands;
    }
  });

  // js/shims/codemirror-search.js
  var require_codemirror_search = __commonJS({
    "js/shims/codemirror-search.js"(exports, module) {
      module.exports = globalThis.__CM__search;
    }
  });

  // js/shims/codemirror-autocomplete.js
  var require_codemirror_autocomplete = __commonJS({
    "js/shims/codemirror-autocomplete.js"(exports, module) {
      module.exports = globalThis.__CM__autocomplete;
    }
  });

  // js/shims/codemirror-lint.js
  var require_codemirror_lint = __commonJS({
    "js/shims/codemirror-lint.js"(exports, module) {
      module.exports = globalThis.__CM__lint;
    }
  });

  // node_modules/codemirror/dist/index.js
  var dist_exports = {};
  __export(dist_exports, {
    EditorView: () => import_view2.EditorView,
    basicSetup: () => basicSetup,
    minimalSetup: () => minimalSetup
  });
  var import_view = __toESM(require_codemirror_view(), 1);
  var import_view2 = __toESM(require_codemirror_view(), 1);
  var import_state = __toESM(require_codemirror_state(), 1);
  var import_language = __toESM(require_codemirror_language(), 1);
  var import_commands = __toESM(require_codemirror_commands(), 1);
  var import_search = __toESM(require_codemirror_search(), 1);
  var import_autocomplete = __toESM(require_codemirror_autocomplete(), 1);
  var import_lint = __toESM(require_codemirror_lint(), 1);
  var basicSetup = /* @__PURE__ */ (() => [
    (0, import_view.lineNumbers)(),
    (0, import_view.highlightActiveLineGutter)(),
    (0, import_view.highlightSpecialChars)(),
    (0, import_commands.history)(),
    (0, import_language.foldGutter)(),
    (0, import_view.drawSelection)(),
    (0, import_view.dropCursor)(),
    import_state.EditorState.allowMultipleSelections.of(true),
    (0, import_language.indentOnInput)(),
    (0, import_language.syntaxHighlighting)(import_language.defaultHighlightStyle, { fallback: true }),
    (0, import_language.bracketMatching)(),
    (0, import_autocomplete.closeBrackets)(),
    (0, import_autocomplete.autocompletion)(),
    (0, import_view.rectangularSelection)(),
    (0, import_view.crosshairCursor)(),
    (0, import_view.highlightActiveLine)(),
    (0, import_search.highlightSelectionMatches)(),
    import_view.keymap.of([
      ...import_autocomplete.closeBracketsKeymap,
      ...import_commands.defaultKeymap,
      ...import_search.searchKeymap,
      ...import_commands.historyKeymap,
      ...import_language.foldKeymap,
      ...import_autocomplete.completionKeymap,
      ...import_lint.lintKeymap
    ])
  ])();
  var minimalSetup = /* @__PURE__ */ (() => [
    (0, import_view.highlightSpecialChars)(),
    (0, import_commands.history)(),
    (0, import_view.drawSelection)(),
    (0, import_language.syntaxHighlighting)(import_language.defaultHighlightStyle, { fallback: true }),
    import_view.keymap.of([
      ...import_commands.defaultKeymap,
      ...import_commands.historyKeymap
    ])
  ])();

  // js/entries/codemirror.js
  globalThis.__CM__codemirror = dist_exports;
})();
