import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const output = readFileSync(process.argv[2]);
const expected = readFileSync(process.argv[3]);
const marker = Buffer.from("\nSource: ");
const start = output.indexOf(marker);
assert.ok(start >= 0, "Terminal source marker is missing");
const text = start + marker.length;
assert.deepEqual(output.subarray(text, text + expected.length), expected);
assert.deepEqual(output.subarray(text + expected.length,
  text + expected.length + 24), Buffer.from("\nEnter replacement text,"));
assert.equal(output.indexOf(marker, text), -1, "Unexpected second startup checkpoint");
