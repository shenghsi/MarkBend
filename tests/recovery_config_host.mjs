import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";

const source = readFileSync(new URL("../src/recovery_config.js", import.meta.url), "utf8")
  .replace(/CID\(([^)]+)\)/g, (_, name) => JSON.stringify(name));
function read(env, bun = false) {
  let effect;
  const context = { TextEncoder, io_eff: (_, fn) => { effect = fn; },
    io_tup: (a, b) => [a, b], io_done: value => ({ $: "Done", value }) };
  if (env !== undefined) context.process = { env };
  if (bun) context.Bun = { spawnSync() {} };
  runInNewContext(source, context);
  return effect();
}
function bytes(value) {
  assert.equal(value.$, "Some");
  const raw = [];
  for (let list = value.value; list.$ === "Con"; list = list.tail) raw.push(list.head);
  return raw;
}
const names = ["MARKBEND_STARTUP_RECOVERY_HOST", "MARKBEND_STARTUP_RECOVERY_ROOT"];
const env = { [names[0]]: "./中文 😀 host", [names[1]]: "./目录 😀" };
for (const supported of [false, true]) {
  const result = read(env, supported);
  assert.equal(result.$, "Done");
  assert.equal(result.value[0], supported);
  assert.deepEqual(bytes(result.value[1][0]), Array.from(new TextEncoder().encode(env[names[0]])));
  assert.deepEqual(bytes(result.value[1][1]), Array.from(new TextEncoder().encode(env[names[1]])));
}
for (const name of names) {
  for (const invalid of ["\ud800", "\udc00", "x\ud800x", 42]) {
    const result = read({ ...env, [name]: invalid });
    assert.equal(result.$, "Fail");
    assert.equal(result.error[0], 22);
  }
}
const browser = read(undefined);
assert.equal(browser.value[0], false);
assert.equal(browser.value[1][0].$, "None");
assert.equal(browser.value[1][1].$, "None");
const empty = read({ [names[0]]: "", [names[1]]: "" });
assert.deepEqual(bytes(empty.value[1][0]), []);
assert.deepEqual(bytes(empty.value[1][1]), []);
console.log("Recovery config raw bytes, booleans, browser, and invalid host strings passed");
