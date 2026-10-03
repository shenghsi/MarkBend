import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const root = fs.mkdtempSync(path.join(os.tmpdir(), "markbend-app-save-js-"));
const file = path.join(root, "中文 😀.md");
const untitled = process.argv[3] === "untitled";
const diskOriginal = "A\r\n";
const original = untitled ? "Edit this paragraph. 中文输入 and 日本語入力 are welcome." : diskOriginal;
const edited = "\uFEFF中文😀\r\né\0\n";
fs.writeFileSync(file, diskOriginal);
if (untitled) delete process.env.MARKBEND_OPEN_PATH; else process.env.MARKBEND_OPEN_PATH = file;
delete process.env.MARKBEND_STARTUP_RECOVERY_HOST;
delete process.env.MARKBEND_STARTUP_RECOVERY_ROOT;
const replies = [edited, ".save", ".close", "cancel", ".undo", ".redo", ".close", "discard"];
const sources = [original, edited, edited, "cancel", edited, original, edited, "cancel"];
if (untitled) {
  // Save on close must return to the same editor before a later explicit choice.
  replies.splice(6, 0, ".close", "save");
  sources.splice(6, 0, edited, "cancel");
}
const cycles = process.argv[3] === "cycles" ? 10000 : 0;
if (cycles) {
  const repeatedReplies = [], repeatedSources = [];
  for (let cycle = 0; cycle < cycles; cycle++) {
    repeatedReplies.push(".close", "cancel");
    repeatedSources.push(edited, "cancel");
  }
  replies.splice(6, 0, ...repeatedReplies);
  sources.splice(6, 0, ...repeatedSources);
}
const messages = [];
const error = console.error;
console.error = message => messages.push(message);
let at = 0;
globalThis.prompt = (message, source) => {
  assert.ok(at < replies.length, "unexpected extra host prompt");
  assert.equal(source, sources[at]);
  assert.equal(message.startsWith("Unsaved changes."), sources[at] === "cancel");
  assert.deepEqual(fs.readFileSync(file), Buffer.from(diskOriginal));
  return replies[at++];
};
// Bend's generated IO entry point can call process.exit during require.
// Register final assertions first, so they still run on that exit path.
process.on("exit", code => {
  try {
    assert.equal(code, 0);
    assert.equal(at, replies.length);
    assert.deepEqual(messages, untitled ? ["Save As is unavailable for this document",
      "Save As is unavailable for this document"] : ["Save is unavailable on this host"]);
    assert.deepEqual(fs.readFileSync(file), Buffer.from(diskOriginal));
    assert.deepEqual(fs.readdirSync(root), [path.basename(file)]);
    process.stderr.write(untitled ? "Untitled Save and Save-on-close retained editor and exact disk state\n" :
      "App JavaScript save unavailable, Cancel, history, and explicit Discard passed\n");
    if (cycles) process.stderr.write("Ten thousand Cancel choices crossed finite app pump cycles\n");
  } finally {
    console.error = error;
    delete globalThis.prompt;
    fs.rmSync(root, { recursive: true });
  }
});
require(path.resolve(process.argv[2]));
