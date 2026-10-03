import { spawnSync } from "node:child_process";
import assert from "node:assert/strict";
const run = script => spawnSync(process.execPath, ["tests/watchdog.mjs", "200", process.execPath, "-e", script], { encoding: "utf8", timeout: 3000 });
assert.equal(run("process.exit(0)").status, 0);
assert.equal(run("process.exit(7)").status, 7);
const blocked = run("Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0)");
assert.equal(blocked.status, 124);
assert.ok(blocked.stderr.includes("Test watchdog expired"));
console.log("External watchdog preserved exit results and stopped a blocked child");
