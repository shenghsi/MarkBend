import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import assert from "node:assert/strict";

const effects = new Map();
const code = readFileSync(new URL("../src/live_paragraph.js", import.meta.url), "utf8")
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
effects.get("LiveParagraph.project")(state, 2, 4);
assert.equal(state.selection.start, 2);
assert.equal(state.selection.end, 4);
effects.get("LiveParagraph.append")(state, "heading", 4);
assert.equal(state.runs[0].bold, true);
assert.equal(state.runs[0].blockStyle, 4);
effects.get("LiveParagraph.append")(state, "> quote", 10);
assert.equal(state.runs[1].italic, true);
assert.equal(state.runs[1].blockStyle, 10);
const batchTexts = ["", "中文😀\r\n", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j"];
effects.get("LiveParagraph.set")(state, "batch");
batchTexts.forEach((text, style) => effects.get("LiveParagraph.append")(state, text, style));
const singleScene = JSON.stringify(state.runs);
effects.get("LiveParagraph.set")(state, "batch");
let batch = { $: "Nil" };
for (let style = batchTexts.length - 1; style >= 0; style--) {
  batch = { $: "Con", head: { text: batchTexts[style], style }, tail: batch };
}
effects.get("LiveParagraph.append_scene")(state, batch);
assert.equal(JSON.stringify(state.runs), singleScene);
effects.get("LiveParagraph.append_scene")(state, { $: "Nil" });
assert.equal(JSON.stringify(state.runs), singleScene);
const chunks = (items) => items.reduceRight((tail, [id, fresh, text, style = 0]) => ({
  $: "Con", head: { id: BigInt(id), fresh, runs: {
    $: "Con", head: { text, style }, tail: { $: "Nil" }
  } }, tail
}), { $: "Nil" });
const presentChunks = (items, enabled = { $: "True" }) => {
  effects.get("LiveParagraph.set")(state, "chunks");
  effects.get("LiveParagraph.append_chunks")(state, chunks(items), enabled);
  return state.runs.map(run => run.text).join("");
};
assert.equal(presentChunks([[7, true, "old"], [8, true, "tail"]]), "oldtail");
const retainedTail = state.nativeChunks.get(8n);
assert.equal(presentChunks([[7, { $: "True" }, "new"], [8, false, "tail"]]), "newtail");
assert.equal(state.nativeChunks.get(8n), retainedTail);
assert.equal(state.nativeChunks.size, 2);
assert.equal(presentChunks([[99, false, "only"]]), "only");
assert.equal(state.nativeChunks.size, 1);
assert.equal(presentChunks([[99, true, "legacy"]], { $: "False" }), "legacy");
assert.equal(state.nativeChunks.size, 0);
effects.get("LiveParagraph.replace")(state, 0n, 0n, "");
effects.get("LiveParagraph.patch_chunks")(state, { $: "Nil" });
assert.equal(state.runs.map(run => run.text).join(""), "legacy");
assert.equal(presentChunks([[99, false, "restored"]]), "restored");
const patches = (items) => items.reduceRight((tail, [first, removed, start, length, inserted]) => ({
  $: "Con", head: { first: BigInt(first), removed: BigInt(removed), start: BigInt(start),
    length: BigInt(length), chunks: chunks(inserted) }, tail
}), { $: "Nil" });
assert.equal(presentChunks([[41, true, "a😀"], [42, true, ""], [43, true, "tail"]]), "a😀tail");
const tailChunk = state.nativeChunks.get(43n);
effects.get("LiveParagraph.replace")(state, 0n, 0n, "");
effects.get("LiveParagraph.patch_chunks")(state, patches([
  [0, 1, 0, 3, [[41, true, "中文", 1]]],
  [1, 1, 2, 0, [[44, false, "😀"], [45, true, ""]]]
]));
assert.equal(state.runs.map(run => run.text).join(""), "中文😀tail");
assert.equal(state.nativeChunks.get(43n), tailChunk);
assert.equal(state.nativeChunks.has(42n), false);
assert.equal(state.nativeChunks.size, 4);
effects.get("LiveParagraph.replace")(state, 0n, 0n, "");
effects.get("LiveParagraph.patch_chunks")(state, patches([
  [3, 1, 4, 4, []], [0, 1, 0, 2, [[41, true, "中文", 2]]]
]));
const patchedScene = JSON.stringify(state.runs);
assert.equal(state.runs.map(run => run.text).join(""), "中文😀");
assert.equal(state.nativeChunks.has(43n), false);
assert.equal(state.nativeChunks.size, 3);
presentChunks([[41, true, "中文", 2], [44, true, "😀"], [45, true, ""]]);
assert.equal(JSON.stringify(state.runs), patchedScene);
assert.throws(() => effects.get("LiveParagraph.patch_chunks")(state, patches([
  [0, 1, 0, 99, []]
])), /scene patch native range failed/);
presentChunks([]);
effects.get("LiveParagraph.replace")(state, 0n, 0n, "");
effects.get("LiveParagraph.patch_chunks")(state, patches([
  [0, 0, 0, 0, [[(1n << 47n) + 7n, false, "é\r\n"]]], [0, 1, 0, 4, []]
]));
assert.equal(state.runs.length, 0);
assert.equal(state.nativeChunks.size, 0);
assert.equal(state.nativeOrder.length, 0);
// A large insertion must not depend on the JavaScript call argument limit.
let many = { $: "Nil" };
for (let id = 149999; id >= 0; id--) {
  many = { $: "Con", head: { id: BigInt(id), fresh: true, runs: {
    $: "Con", head: { text: "x", style: 0 }, tail: { $: "Nil" }
  } }, tail: many };
}
effects.get("LiveParagraph.patch_chunks")(state, { $: "Con", head: {
  first: 0n, removed: 0n, start: 0n, length: 0n, chunks: many
}, tail: { $: "Nil" } });
assert.equal(state.runs.length, 150000);
assert.equal(state.nativeOrder[149999], 149999n);
effects.get("LiveParagraph.patch_chunks")(state, patches([[0, 150000, 0, 150000, []]]));
assert.equal(state.nativeOrder.length, 0);
assert.equal(state.nativeChunks.size, 0);
const rangeCases = [
  [2n, 3n, "中文日\n\r\né"], [4n, 1n, "中日\n\né"],
  [20n, 10n, "中文😀\r\né日\n"], [0n, 100n, "日\n"],
  [3n, 3n, "中文😀日\n\r\né"]
];
for (const [start, end, expected] of rangeCases) {
  effects.get("LiveParagraph.set")(state, "中文😀\r\né");
  effects.get("LiveParagraph.replace")(state, start, end, "日\n");
  assert.equal(state.initial, expected);
  assert.equal(state.runs.length, 0);
}
effects.get("LiveParagraph.replace")(state, 0n, 0n, "");
assert.equal(state.initial, "中文😀日\n\r\né");
effects.get("LiveParagraph.set")(state, "");
effects.get("LiveParagraph.replace")(state, 0n, 100n, "😀");
assert.equal(state.initial, "😀");
effects.get("LiveParagraph.replace")(state, 10n, 0n, "");
assert.equal(state.initial, "");
console.log("JavaScript host round trip passed");
const commandEffects = new Map();
runInNewContext(code, {
  io_eff: (name, effect) => commandEffects.set(name, effect),
  io_tup: (window, event) => [window, event],
  prompt: () => ".return"
});
const selected = { initial: "- 中😀", selection: { start: 5, end: 5 } };
const [retained, event] = commandEffects.get("LiveParagraph.next")(selected);
assert.equal(retained, selected);
assert.equal(selected.initial, "- 中😀");
assert.deepEqual(JSON.parse(JSON.stringify(event)), { $: "ParagraphReturn", start: 5, end: 5 });
console.log("JavaScript Return dispatch preserves the projected selection and source");
