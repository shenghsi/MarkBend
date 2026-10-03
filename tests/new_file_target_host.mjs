import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

const [runtime, program, swapProgram] = process.argv.slice(2);
const executable = path.resolve(program);
const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "markbend-target-host-")));
const parent = path.join(root, "parent");
fs.mkdirSync(parent);
const alias = path.join(root, "alias");
fs.symlinkSync(parent, alias);
const guard = path.join(parent, "guard.md"); fs.writeFileSync(guard, "guard\r\n\0");
fs.mkdirSync(path.join(parent, "directory"));
fs.symlinkSync("missing", path.join(parent, "dangling"));
function run(request, expected, directory = root) {
  const native = runtime === "native";
  const target = native ? expected : "-";
  const info = target === "-" ? null : fs.statSync(path.dirname(target), { bigint: true });
  const key = info ? `DIR1:${info.dev}:${info.ino}` : "-";
  const args = [request, target, key];
  const result = spawnSync(native ? executable : runtime, native ? args : [executable, ...args], {
    cwd: directory, encoding: "utf8", timeout: 10000,
  });
  assert.equal(result.status, 0, `${request}: ${result.error || result.stderr}`);
  assert.ok(result.stdout.includes("New-file target host result passed"));
}
try {
  run(path.join(alias, "中文 😀.md"), path.join(parent, "中文 😀.md"));
  run("parent/new.md", path.join(parent, "new.md"));
  run(`/markbend-read-only-target-${process.pid}.md`, `/markbend-read-only-target-${process.pid}.md`);
  for (const request of ["", "parent/", "parent/.", "parent/..", guard,
    path.join(parent, "directory"), path.join(parent, "dangling"), "missing/new.md"])
    run(request, "-");
  const invalid = Buffer.concat([Buffer.from(root + "/"), Buffer.from([255])]);
  let invalidCreated = false;
  try { fs.mkdirSync(invalid); invalidCreated = true; }
  catch (error) {
    if (error.code !== "EILSEQ") throw error;
    console.log("Filesystem rejected the invalid-UTF-8 parent fixture (EILSEQ)");
  }
  if (invalidCreated) {
    const invalidAlias = path.join(root, "invalid-parent"); fs.symlinkSync(invalid, invalidAlias);
    run(path.join(invalidAlias, "new.md"), "-");
  }
  assert.deepEqual(fs.readFileSync(guard), Buffer.from("guard\r\n\0"));
  assert.deepEqual(fs.readdirSync(parent).sort(), ["dangling", "directory", "guard.md"]);
  if (swapProgram) {
    const swapParent = path.join(root, "swap-parent"), backup = path.join(root, "swap-backup");
    fs.mkdirSync(swapParent); fs.writeFileSync(path.join(swapParent, "guard"), "old parent");
    const result = spawnSync(path.resolve(swapProgram), [path.join(swapParent, "new.md"), "-", "-"], {
      encoding: "utf8", timeout: 10000,
      env: { ...process.env, MARKBEND_NEW_TARGET_SWAP_PARENT: swapParent, MARKBEND_NEW_TARGET_SWAP_BACKUP: backup },
    });
    assert.equal(result.status, 0, result.error || result.stderr);
    assert.ok(result.stdout.includes("New-file target host result passed"));
    assert.deepEqual(fs.readdirSync(swapParent), []);
    assert.deepEqual(fs.readdirSync(backup), ["guard"]);
    assert.equal(fs.readFileSync(path.join(backup, "guard"), "utf8"), "old parent");
    console.log("Actual target effect rejected replaced parent and retained fixture bytes");
  }
  console.log(`New-file target path and raw identity cases passed (${runtime})`);
} finally { fs.rmSync(root, { recursive: true }); }
