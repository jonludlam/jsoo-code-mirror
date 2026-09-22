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

  // js/shims/codemirror-language.js
  var require_codemirror_language = __commonJS({
    "js/shims/codemirror-language.js"(exports, module) {
      module.exports = globalThis.__CM__language;
    }
  });

  // js/shims/lezer-highlight.js
  var require_lezer_highlight = __commonJS({
    "js/shims/lezer-highlight.js"(exports, module) {
      module.exports = globalThis.__CM__lezer_highlight;
    }
  });

  // node_modules/@codemirror/theme-one-dark/dist/index.js
  var dist_exports = {};
  __export(dist_exports, {
    color: () => color,
    oneDark: () => oneDark,
    oneDarkHighlightStyle: () => oneDarkHighlightStyle,
    oneDarkTheme: () => oneDarkTheme
  });
  var import_view = __toESM(require_codemirror_view(), 1);
  var import_language = __toESM(require_codemirror_language(), 1);
  var import_highlight = __toESM(require_lezer_highlight(), 1);
  var chalky = "#e5c07b";
  var coral = "#e06c75";
  var cyan = "#56b6c2";
  var invalid = "#ffffff";
  var ivory = "#abb2bf";
  var stone = "#7d8799";
  var malibu = "#61afef";
  var sage = "#98c379";
  var whiskey = "#d19a66";
  var violet = "#c678dd";
  var darkBackground = "#21252b";
  var highlightBackground = "#2c313a";
  var background = "#282c34";
  var tooltipBackground = "#353a42";
  var selection = "#3E4451";
  var cursor = "#528bff";
  var color = {
    chalky,
    coral,
    cyan,
    invalid,
    ivory,
    stone,
    malibu,
    sage,
    whiskey,
    violet,
    darkBackground,
    highlightBackground,
    background,
    tooltipBackground,
    selection,
    cursor
  };
  var oneDarkTheme = /* @__PURE__ */ import_view.EditorView.theme({
    "&": {
      color: ivory,
      backgroundColor: background
    },
    ".cm-content": {
      caretColor: cursor
    },
    ".cm-cursor, .cm-dropCursor": { borderLeftColor: cursor },
    "&.cm-focused > .cm-scroller > .cm-selectionLayer .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection": { backgroundColor: selection },
    ".cm-panels": { backgroundColor: darkBackground, color: ivory },
    ".cm-panels.cm-panels-top": { borderBottom: "2px solid black" },
    ".cm-panels.cm-panels-bottom": { borderTop: "2px solid black" },
    ".cm-searchMatch": {
      backgroundColor: "#72a1ff59",
      outline: "1px solid #457dff"
    },
    ".cm-searchMatch.cm-searchMatch-selected": {
      backgroundColor: "#6199ff2f"
    },
    ".cm-activeLine": { backgroundColor: "#6699ff0b" },
    ".cm-selectionMatch": { backgroundColor: "#aafe661a" },
    "&.cm-focused .cm-matchingBracket, &.cm-focused .cm-nonmatchingBracket": {
      backgroundColor: "#bad0f847"
    },
    ".cm-gutters": {
      backgroundColor: background,
      color: stone,
      border: "none"
    },
    ".cm-activeLineGutter": {
      backgroundColor: highlightBackground
    },
    ".cm-foldPlaceholder": {
      backgroundColor: "transparent",
      border: "none",
      color: "#ddd"
    },
    ".cm-tooltip": {
      border: "none",
      backgroundColor: tooltipBackground
    },
    ".cm-tooltip .cm-tooltip-arrow:before": {
      borderTopColor: "transparent",
      borderBottomColor: "transparent"
    },
    ".cm-tooltip .cm-tooltip-arrow:after": {
      borderTopColor: tooltipBackground,
      borderBottomColor: tooltipBackground
    },
    ".cm-tooltip-autocomplete": {
      "& > ul > li[aria-selected]": {
        backgroundColor: highlightBackground,
        color: ivory
      }
    }
  }, { dark: true });
  var oneDarkHighlightStyle = /* @__PURE__ */ import_language.HighlightStyle.define([
    {
      tag: import_highlight.tags.keyword,
      color: violet
    },
    {
      tag: [import_highlight.tags.name, import_highlight.tags.deleted, import_highlight.tags.character, import_highlight.tags.propertyName, import_highlight.tags.macroName],
      color: coral
    },
    {
      tag: [/* @__PURE__ */ import_highlight.tags.function(import_highlight.tags.variableName), import_highlight.tags.labelName],
      color: malibu
    },
    {
      tag: [import_highlight.tags.color, /* @__PURE__ */ import_highlight.tags.constant(import_highlight.tags.name), /* @__PURE__ */ import_highlight.tags.standard(import_highlight.tags.name)],
      color: whiskey
    },
    {
      tag: [/* @__PURE__ */ import_highlight.tags.definition(import_highlight.tags.name), import_highlight.tags.separator],
      color: ivory
    },
    {
      tag: [import_highlight.tags.typeName, import_highlight.tags.className, import_highlight.tags.number, import_highlight.tags.changed, import_highlight.tags.annotation, import_highlight.tags.modifier, import_highlight.tags.self, import_highlight.tags.namespace],
      color: chalky
    },
    {
      tag: [import_highlight.tags.operator, import_highlight.tags.operatorKeyword, import_highlight.tags.url, import_highlight.tags.escape, import_highlight.tags.regexp, import_highlight.tags.link, /* @__PURE__ */ import_highlight.tags.special(import_highlight.tags.string)],
      color: cyan
    },
    {
      tag: [import_highlight.tags.meta, import_highlight.tags.comment],
      color: stone
    },
    {
      tag: import_highlight.tags.strong,
      fontWeight: "bold"
    },
    {
      tag: import_highlight.tags.emphasis,
      fontStyle: "italic"
    },
    {
      tag: import_highlight.tags.strikethrough,
      textDecoration: "line-through"
    },
    {
      tag: import_highlight.tags.link,
      color: stone,
      textDecoration: "underline"
    },
    {
      tag: import_highlight.tags.heading,
      fontWeight: "bold",
      color: coral
    },
    {
      tag: [import_highlight.tags.atom, import_highlight.tags.bool, /* @__PURE__ */ import_highlight.tags.special(import_highlight.tags.variableName)],
      color: whiskey
    },
    {
      tag: [import_highlight.tags.processingInstruction, import_highlight.tags.string, import_highlight.tags.inserted],
      color: sage
    },
    {
      tag: import_highlight.tags.invalid,
      color: invalid
    }
  ]);
  var oneDark = [oneDarkTheme, /* @__PURE__ */ (0, import_language.syntaxHighlighting)(oneDarkHighlightStyle)];

  // js/entries/theme_one_dark.js
  globalThis.__CM__theme_one_dark = dist_exports;
})();
