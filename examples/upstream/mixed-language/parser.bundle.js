var __grammar = (() => {
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
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

  // js/shims/lezer-lr.js
  var require_lezer_lr = __commonJS({
    "js/shims/lezer-lr.js"(exports, module) {
      module.exports = globalThis.__CM__lezer_lr;
    }
  });

  // js/shims/lezer-highlight.js
  var require_lezer_highlight = __commonJS({
    "js/shims/lezer-highlight.js"(exports, module) {
      module.exports = globalThis.__CM__lezer_highlight;
    }
  });

  // examples/upstream/mixed-language/parser.js
  var parser_exports = {};
  __export(parser_exports, {
    parser: () => parser
  });
  var import_lr = __toESM(require_lezer_lr());

  // examples/upstream/mixed-language/twig-highlight.js
  var import_highlight = __toESM(require_lezer_highlight());
  var twigHighlight = (0, import_highlight.styleTags)({
    "if endif": import_highlight.tags.controlKeyword,
    "{{ }} {% %}": import_highlight.tags.meta,
    DirectiveContent: import_highlight.tags.variableName
  });

  // examples/upstream/mixed-language/parser.js
  var spec_Identifier = { __proto__: null, if: 20, endif: 26 };
  var parser = import_lr.LRParser.deserialize({
    version: 14,
    states: "#fQVOPOOObQQO'#C^OgOPO'#CbOOOO'#Co'#CoOOOO'#Ck'#CkQVOPOOOrQSO'#CcOwQQO,58xOOOO,58|,58|OgOPO,58|O|QSO'#ChOOOO-E6i-E6iO!UQQO,58}OOOO1G.d1G.dOOOO1G.h1G.hO!ZQQO,59SO!`QQO1G.iOOOO1G.n1G.nOOOO7+$T7+$T",
    stateData: "!h~ObOS~ORPOWUO^SO~OSVO~ORPOWYO^SO~OY[O~OT]O~OY[O]_O~OS`O~OZaO~OZbO~ObS~",
    goto: "!XdPPePPPekPPPPqPPwPPP!RXROQTXXQOQTXQWQR^XQTOQXQTZTXXSOQTX",
    nodeNames: "\u26A0 Template Insert {{ DirectiveContent }} Conditional ConditionalOpen {% Identifier if %} ConditionalClose endif Text",
    maxTerm: 19,
    propSources: [twigHighlight],
    skippedNodes: [0, 9],
    repeatNodeCount: 1,
    tokenData: "/`VRpOX#VX^(O^p#Vpq(Oqu#Vuv*Sv!c#V!c!}+[!}#T#V#T#o+[#o#p,Z#p#q#V#q#r.W#r#y#V#y#z(O#z$f#V$f$g(O$g#BY#V#BY#BZ(O#BZ$IS#V$IS$I_(O$I_$I|#V$I|$JO(O$JO$JT#V$JT$JU(O$JU$KV#V$KV$KW(O$KW&FU#V&FU&FV(O&FV;'S#V;'S;=`&o<%lO#VR#^X^PSQOu#Vuv#yv#o#V#o#p$k#p#q#V#q#r#y#r;'S#V;'S;=`&o<%lO#VR$OX^PO#o#V#o#p$k#p#q#V#q#r&z#r;'S#V;'S;=`&o<%l~#V~O#V~~&jR$pZSQOu#Vuv%cv#o#V#o#p%x#p#q#V#q#r#y#r;'S#V;'S;=`&o<%l~#V~O#V~~&uQ%fUO#q%x#r;'S%x;'S;=`&d<%l~%x~O%x~~&jQ%}VSQOu%xuv%cv#q%x#q#r%c#r;'S%x;'S;=`&d<%lO%xQ&gP;=`<%l%xQ&oOSQR&rP;=`<%l#VP&zO^PP'PT^PO#o&z#o#p'`#p;'S&z;'S;=`'x<%lO&zP'cVOu&zv#o&z#p;'S&z;'S;=`'x<%l~&z~O&z~~&uP'{P;=`<%l&zV(Xm^PbUSQOX#VX^(O^p#Vpq(Oqu#Vuv#yv#o#V#o#p$k#p#q#V#q#r#y#r#y#V#y#z(O#z$f#V$f$g(O$g#BY#V#BY#BZ(O#BZ$IS#V$IS$I_(O$I_$I|#V$I|$JO(O$JO$JT#V$JT$JU(O$JU$KV#V$KV$KW(O$KW&FU#V&FU&FV(O&FV;'S#V;'S;=`&o<%lO#VR*XX^PO#o#V#o#p$k#p#q#V#q#r*t#r;'S#V;'S;=`&o<%l~#V~O#V~~&jR*{TZQ^PO#o&z#o#p'`#p;'S&z;'S;=`'x<%lO&zV+e[XS^PSQOu#Vuv#yv!c#V!c!}+[!}#T#V#T#o+[#o#p$k#p#q#V#q#r#y#r;'S#V;'S;=`&o<%lO#VR,`ZSQOu#Vuv-Rv#o#V#o#p-j#p#q#V#q#r#y#r;'S#V;'S;=`&o<%l~#V~O#V~~&uR-WUWPO#q%x#r;'S%x;'S;=`&d<%l~%x~O%x~~&jR-qVRPSQOu%xuv%cv#q%x#q#r%c#r;'S%x;'S;=`&d<%lO%xR.]X^PO#o#V#o#p$k#p#q#V#q#r.x#r;'S#V;'S;=`&o<%l~#V~O#V~~&jR/PTTQ^PO#o&z#o#p'`#p;'S&z;'S;=`'x<%lO&z",
    tokenizers: [0, 1, 2],
    topRules: { "Template": [0, 1] },
    specialized: [{ term: 9, get: (value) => spec_Identifier[value] || -1 }],
    tokenPrec: 67
  });
  return __toCommonJS(parser_exports);
})();
globalThis.__twig_grammar = __grammar;
