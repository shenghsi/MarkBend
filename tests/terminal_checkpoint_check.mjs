import assert from "node:assert/strict";
import { completeCheckpoint } from "./terminal_checkpoint.mjs";
const header = Buffer.from("--- MarkBend multiline checkpoint ---");
const prefix = Buffer.from("\nSource: ");
const suffix = Buffer.from("\nEnter replacement text,");
const first = Buffer.concat([header, prefix, Buffer.from("A\r\n"), suffix]);
const source = Buffer.from("\uFEFF中文😀\r\né\0\n");
const second = Buffer.concat([header, prefix, source, suffix]);
for (let n = header.length; n < second.length; n++) {
  assert.equal(completeCheckpoint(Buffer.concat([first, second.subarray(0, n)])), null);
}
const complete = Buffer.concat([first, second]);
const frame = completeCheckpoint(complete);
assert.equal(frame.count, 2);
assert.deepEqual(complete.subarray(frame.start, frame.start + source.length), source);
console.log("Split checkpoint header, Unicode, NUL, and suffix checks passed");
