// @codemirror/language and the lezer packages it brings; commands and
// autocomplete reach lezer through these globals.
import * as language from "@codemirror/language";
import * as common from "@lezer/common";
import * as highlight from "@lezer/highlight";
import * as lr from "@lezer/lr";
globalThis.__CM__language = language;
globalThis.__CM__lezer_common = common;
globalThis.__CM__lezer_highlight = highlight;
globalThis.__CM__lezer_lr = lr;
