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

  // examples/upstream/lang-package/parser.js
  var parser_exports = {};
  __export(parser_exports, {
    parser: () => parser
  });
  var import_lr = __toESM(require_lezer_lr());
  var parser = import_lr.LRParser.deserialize({
    version: 14,
    states: "!WQYQPOOOhQPO'#CdOOQO'#Ci'#CiOOQO'#Ce'#CeQYQPOOOOQO,59O,59OOyQPO,59OOOQO-E6c-E6cOOQO1G.j1G.j",
    stateData: "![~O[OSPOS~ORQOSQOTQOVPO~ORQOSQOTQOUTOVPO~ORQOSQOTQOUWOVPO~O",
    goto: "u^PPPPPPPP_ePPPoXQOPSUQSOQUPTVSUXROPSU",
    nodeNames: "\u26A0 LineComment Program Identifier String Boolean ) ( Application",
    maxTerm: 13,
    nodeProps: [
      ["openedBy", 6, "("],
      ["closedBy", 7, ")"]
    ],
    skippedNodes: [0, 1],
    repeatNodeCount: 1,
    tokenData: "%V~R[XYwYZw]^wpqwrs!Yst#vxy$Uyz$Z!]!^$`!c!}$w#R#S$w#T#o$w~|S[~XYwYZw]^wpqw~!]VOr!Yrs!rs#O!Y#O#P!w#P;'S!Y;'S;=`#p<%lO!Y~!wOS~~!zRO;'S!Y;'S;=`#T;=`O!Y~#WWOr!Yrs!rs#O!Y#O#P!w#P;'S!Y;'S;=`#p;=`<%l!Y<%lO!Y~#sP;=`<%l!Y~#yQ#Y#Z$P#h#i$P~$UOT~~$ZOV~~$`OU~~$eSP~OY$`Z;'S$`;'S;=`$q<%lO$`~$tP;=`<%l$`~$|RR~!c!}$w#R#S$w#T#o$w",
    tokenizers: [0],
    topRules: { "Program": [0, 2] },
    tokenPrec: 0
  });
  return __toCommonJS(parser_exports);
})();
globalThis.__example_grammar = __grammar;
