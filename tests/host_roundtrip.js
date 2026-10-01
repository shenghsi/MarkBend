import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import assert from "node:assert/strict";

const effects = new Map();
const code = readFileSync(new URL("../live_paragraph.js", import.meta.url), "utf8")
  .replace(/CID\(([^)]+)\)/g, '"$1"');
runInNewContext(code, { io_eff: (name, effect) => effects.set(name, effect) });
let state = effects.get("LiveParagraph.open")("initial");
state = effects.get("LiveParagraph.set")(state, "中文 **one**\n**two**");
for (const [text, bold] of [["中文 ", 0], ["one", 1], ["\n", 0], ["two", 1]]) {
  state = effects.get("LiveParagraph.append")(state, text, bold);
}
assert.equal(state.initial, "中文 **one**\n**two**");
assert.equal(JSON.stringify(state.runs), JSON.stringify([
  { text: "中文 ", bold: false, italic: false, code: false }, { text: "one", bold: true, italic: false, code: false },
  { text: "\n", bold: false, italic: false, code: false }, { text: "two", bold: true, italic: false, code: false }
]));
effects.get("LiveParagraph.append")(state, "italic", 2);
assert.equal(state.runs[4].italic, true);
assert.equal(state.runs[4].bold, false);
effects.get("LiveParagraph.append")(state, "**literal**", 3);
assert.equal(state.runs[5].code, true);
assert.equal(state.runs[5].bold, false);
effects.get("LiveParagraph.set")(state, "unfinished **");
assert.equal(state.runs.length, 0);
console.log("JavaScript host round trip passed");
