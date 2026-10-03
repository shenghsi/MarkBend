import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import assert from "node:assert/strict";

const source = readFileSync(new URL("../src/open_config.js", import.meta.url), "utf8")
  .replace(/CID\(([^)]+)\)/g, '"$1"');
let read;
const context = { TextEncoder, io_eff: (_, effect) => { read = effect; } };
runInNewContext(source, context);
assert.equal(read().$, "None");
context.process = { env: { MARKBEND_OPEN_PATH: "\ud800" } };
assert.throws(() => read(), /Invalid startup path encoding/);
context.process.env.MARKBEND_OPEN_PATH = "\udc00";
assert.throws(() => read(), /Invalid startup path encoding/);
context.process.env.MARKBEND_OPEN_PATH = "中文😀";
const value = read();
assert.equal(value.$, "Some");
const bytes = [];
for (let cell = value.value; cell.$ !== "Nil"; cell = cell.tail) bytes.push(cell.head);
assert.deepEqual(bytes, [...new TextEncoder().encode("中文😀")]);
console.log("Browser configuration and surrogate checks passed");
