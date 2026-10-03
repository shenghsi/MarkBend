import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { completeCheckpoint } from "./terminal_checkpoint.mjs";

const edited = Buffer.from("\uFEFF中文😀\r\né\0\n");
const original = Buffer.from("A\r\n");
const external = Buffer.from("external\r\n");
const checkpoint = Buffer.from("--- MarkBend multiline checkpoint ---");
const sourcePrefix = Buffer.from("\nSource: ");
const sourceSuffix = Buffer.from("\nEnter replacement text,");

async function run(mode, app) {
  const untitled = mode === "untitled";
  const initial = untitled ? Buffer.from("Edit this paragraph. 中文输入 and 日本語入力 are welcome.") : original;
  const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "markbend-terminal-failure-")));
  const file = path.join(root, "中文 😀.md");
  fs.writeFileSync(file, original);
  const env = { ...process.env, MARKBEND_OPEN_PATH: file };
  if (untitled) delete env.MARKBEND_OPEN_PATH;
  delete env.MARKBEND_STARTUP_RECOVERY_HOST;
  delete env.MARKBEND_STARTUP_RECOVERY_ROOT;
  const child = spawn(path.resolve(app), [], { env, stdio: ["pipe", "pipe", "pipe"] });
  let output = Buffer.alloc(0), step = 0, failure;
  const status = untitled ? "Save As is unavailable for this document" :
    mode === "conflict" ? "The file changed on disk. Save stopped" :
    "Save failed. The file was not replaced";
  const disk = () => untitled ? assert.deepEqual(fs.readFileSync(file), original) :
    mode === "conflict" ? assert.deepEqual(fs.readFileSync(file), external) :
    assert.equal(fs.existsSync(file), false);
  const exactSource = expected => {
    const start = output.lastIndexOf(sourcePrefix) + sourcePrefix.length;
    assert.ok(start >= sourcePrefix.length);
    assert.deepEqual(output.subarray(start, start + expected.length), expected);
    assert.deepEqual(output.subarray(start + expected.length, start + expected.length + sourceSuffix.length), sourceSuffix);
  };
  const timer = setTimeout(() => {
    failure = new Error(`terminal ${mode} timeout at step ${step}`);
    child.kill("SIGTERM");
  }, 15000);
  const observe = bytes => {
    output = Buffer.concat([output, bytes]);
    if (failure) return;
    // Wait for the complete last source checkpoint; chunks can split anywhere.
    const frame = completeCheckpoint(output);
    if (!frame) return;
    const { count } = frame;
    try {
      if (step === 0 && count === 1) {
        exactSource(initial); step++;
        child.stdin.write(Buffer.concat([edited, Buffer.from(".apply\n")]));
      } else if (step === 1 && count === 2) {
        exactSource(edited);
        if (mode === "conflict") fs.writeFileSync(file, external);
        if (mode === "missing") fs.unlinkSync(file);
        step++; child.stdin.write(".save\n");
      } else if (step === 2 && count === 3 && output.includes(Buffer.from(status))) {
        exactSource(edited); disk(); step++; child.stdin.write(untitled ? ".close\n.save\n" : ".close\n.cancel\n");
      } else if (untitled && step === 3 && count === 4) {
        exactSource(edited); disk(); step++; child.stdin.write(".close\n.cancel\n");
      } else if (untitled && step === 4 && count === 5) {
        exactSource(edited); disk(); step++; child.stdin.write(".undo\n");
      } else if (untitled && step === 5 && count === 6) {
        exactSource(initial); disk(); step++; child.stdin.write(".redo\n");
      } else if (untitled && step === 6 && count === 7) {
        exactSource(edited); disk(); step++; child.stdin.end(".close\n.discard\n");
      } else if (!untitled && step === 3 && count === 4) {
        exactSource(edited); disk(); step++; child.stdin.write(".undo\n");
      } else if (!untitled && step === 4 && count === 5) {
        exactSource(original); disk(); step++; child.stdin.write(".redo\n");
      } else if (!untitled && step === 5 && count === 6) {
        exactSource(edited); disk(); step++; child.stdin.end(".close\n.discard\n");
      }
    } catch (error) { failure = error; child.kill("SIGTERM"); }
  };
  child.stderr.on("data", observe);
  child.stdout.on("data", observe);
  child.stdin.on("error", error => {
    failure = failure || new Error(`terminal ${mode} input failed at step ${step}: ${error.message}`);
    child.kill("SIGTERM");
  });
  try {
    const [code, signal] = await new Promise((resolve, reject) => {
      child.on("error", reject); child.on("close", (code, signal) => resolve([code, signal]));
    });
    if (failure) {
      process.stderr.write(output);
      throw failure;
    }
    assert.equal(code, 0); assert.equal(signal, null); assert.equal(step, untitled ? 7 : 6);
    disk(); assert.ok(output.includes(Buffer.from("Unsaved changes.")));
    assert.equal(fs.readdirSync(root).some(name => name.startsWith(".markbend-save-")), false);
    if (untitled) {
      assert.equal(output.toString("utf8").split(status).length - 1, 2);
      assert.deepEqual(fs.readdirSync(root), [path.basename(file)]);
    }
    process.stdout.write(`Terminal app ${mode} retained source, history, Cancel, and disk state\n`);
  } finally {
    clearTimeout(timer);
    fs.rmSync(root, { recursive: true });
  }
}
for (const mode of ["conflict", "missing", "untitled"]) await run(mode, process.argv[2]);
