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

  // js/shims/codemirror-state.js
  var require_codemirror_state = __commonJS({
    "js/shims/codemirror-state.js"(exports, module) {
      module.exports = globalThis.__CM__state;
    }
  });

  // node_modules/@codemirror/collab/dist/index.js
  var dist_exports = {};
  __export(dist_exports, {
    collab: () => collab,
    getClientID: () => getClientID,
    getSyncedVersion: () => getSyncedVersion,
    rebaseUpdates: () => rebaseUpdates,
    receiveUpdates: () => receiveUpdates,
    sendableUpdates: () => sendableUpdates
  });
  var import_state = __toESM(require_codemirror_state(), 1);
  var LocalUpdate = class {
    constructor(origin, changes, effects, clientID) {
      this.origin = origin;
      this.changes = changes;
      this.effects = effects;
      this.clientID = clientID;
    }
  };
  var CollabState = class {
    constructor(version, unconfirmed) {
      this.version = version;
      this.unconfirmed = unconfirmed;
    }
  };
  var collabConfig = /* @__PURE__ */ import_state.Facet.define({
    combine(configs) {
      let combined = (0, import_state.combineConfig)(configs, { startVersion: 0, clientID: null, sharedEffects: () => [] }, {
        generatedID: (a) => a
      });
      if (combined.clientID == null)
        combined.clientID = configs.length && configs[0].generatedID || "";
      return combined;
    }
  });
  var collabReceive = /* @__PURE__ */ import_state.Annotation.define();
  var collabField = /* @__PURE__ */ import_state.StateField.define({
    create(state) {
      return new CollabState(state.facet(collabConfig).startVersion, []);
    },
    update(collab2, tr) {
      let isSync = tr.annotation(collabReceive);
      if (isSync)
        return isSync;
      let { sharedEffects, clientID } = tr.startState.facet(collabConfig);
      let effects = sharedEffects(tr);
      if (effects.length || !tr.changes.empty)
        return new CollabState(collab2.version, collab2.unconfirmed.concat(new LocalUpdate(tr, tr.changes, effects, clientID)));
      return collab2;
    }
  });
  function collab(config = {}) {
    return [collabField, collabConfig.of(Object.assign({ generatedID: Math.floor(Math.random() * 1e9).toString(36) }, config))];
  }
  function receiveUpdates(state, updates) {
    let { version, unconfirmed } = state.field(collabField);
    let { clientID } = state.facet(collabConfig);
    version += updates.length;
    let effects = [], changes = null;
    let own = 0;
    for (let update of updates) {
      let ours = own < unconfirmed.length ? unconfirmed[own] : null;
      if (ours && ours.clientID == update.clientID) {
        if (changes)
          changes = changes.map(ours.changes, true);
        effects = import_state.StateEffect.mapEffects(effects, update.changes);
        own++;
      } else {
        effects = import_state.StateEffect.mapEffects(effects, update.changes);
        if (update.effects)
          effects = effects.concat(update.effects);
        changes = changes ? changes.compose(update.changes) : update.changes;
      }
    }
    if (own)
      unconfirmed = unconfirmed.slice(own);
    if (unconfirmed.length) {
      if (changes)
        unconfirmed = unconfirmed.map((update) => {
          let updateChanges = update.changes.map(changes);
          changes = changes.map(update.changes, true);
          return new LocalUpdate(update.origin, updateChanges, import_state.StateEffect.mapEffects(update.effects, changes), clientID);
        });
      if (effects.length) {
        let composed = unconfirmed.reduce((ch, u) => ch.compose(u.changes), import_state.ChangeSet.empty(unconfirmed[0].changes.length));
        effects = import_state.StateEffect.mapEffects(effects, composed);
      }
    }
    if (!changes)
      return state.update({ annotations: [collabReceive.of(new CollabState(version, unconfirmed))] });
    return state.update({
      changes,
      effects,
      annotations: [
        import_state.Transaction.addToHistory.of(false),
        import_state.Transaction.remote.of(true),
        collabReceive.of(new CollabState(version, unconfirmed))
      ],
      filter: false
    });
  }
  function sendableUpdates(state) {
    return state.field(collabField).unconfirmed;
  }
  function getSyncedVersion(state) {
    return state.field(collabField).version;
  }
  function getClientID(state) {
    return state.facet(collabConfig).clientID;
  }
  function rebaseUpdates(updates, over) {
    if (!over.length || !updates.length)
      return updates;
    let changes = null, skip = 0;
    for (let update of over) {
      let other = skip < updates.length ? updates[skip] : null;
      if (other && other.clientID == update.clientID) {
        if (changes)
          changes = changes.mapDesc(other.changes, true);
        skip++;
      } else {
        changes = changes ? changes.composeDesc(update.changes) : update.changes;
      }
    }
    if (skip)
      updates = updates.slice(skip);
    return !changes ? updates : updates.map((update) => {
      let updateChanges = update.changes.map(changes);
      changes = changes.mapDesc(update.changes, true);
      return {
        changes: updateChanges,
        effects: update.effects && import_state.StateEffect.mapEffects(update.effects, changes),
        clientID: update.clientID
      };
    });
  }

  // js/entries/collab.js
  globalThis.__CM__collab = dist_exports;
})();
