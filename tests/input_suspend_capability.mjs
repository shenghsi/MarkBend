import fs from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";
const effects = new Map();
const code = fs.readFileSync(new URL("../src/live_paragraph.js", import.meta.url), "utf8")
  .replace(/CID\(([^)]+)\)/g, '"$1"');
vm.runInNewContext(code, {
  io_eff: (name, effect) => effects.set(name, effect),
  Atomics: { wait() { throw new TypeError("Unsupported wait host"); } },
});
assert.throws(() => effects.get("LiveParagraph.open")("A"), /cannot retain an input-ended editor session/);
console.log("Unsupported suspension host rejected before editing");
