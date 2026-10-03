import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import { spawn, execFileSync } from "node:child_process";

const [runtime, app, fixture] = process.argv.slice(2);
const notice = "Input ended. Unsaved document retained; resume is unavailable";
const source = "\uFEFF中文😀\r\né\0\n";
for (const mode of fixture === "pending" ? ["pending"] : runtime === "native" ? ["clean", "dirty", "choice_eof", "draft"] : ["clean", "dirty", "choice_eof"]) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "markbend-suspend-"));
  const file = path.join(root, "source.md");
  fs.writeFileSync(file, "A\r\n");
  const native = runtime === "native";
  const values = mode === "clean" ? [null] : mode === "dirty" ? [source, null] : [source, ".close", null];
  const script = `const assert=require('node:assert/strict');const values=${JSON.stringify(values)};let n=0;globalThis.prompt=(message,current)=>{if(n>0&&message.startsWith('MarkBend'))assert.equal(current,${JSON.stringify(source)});if(n>=values.length)throw Error('Repeated input read');return values[n++];};require(${JSON.stringify(path.resolve(app))});`;
  const env = { ...process.env, MARKBEND_OPEN_PATH: file };
  delete env.MARKBEND_STARTUP_RECOVERY_HOST;
  delete env.MARKBEND_STARTUP_RECOVERY_ROOT;
  const child = spawn(native ? path.resolve(app) : runtime, native ? [] : ["-e", script], {
    env,
    stdio: ["pipe", "pipe", "pipe"],
  });
  let output = "", ended = false, failure;
  const closed = new Promise((resolve, reject) => {
    child.on("error", reject);
    child.on("close", (code, signal) => { ended = true; resolve([code, signal]); });
  });
  child.stdout.on("data", b => { output += b.toString(); });
  child.stderr.on("data", b => { output += b.toString(); });
  child.stdin.on("error", error => { failure = error; });
  if (native) child.stdin.end(mode === "clean" ? "" : mode === "draft" ? source : source + ".apply\n" + (mode === "choice_eof" ? ".close\n" : ""));
  else child.stdin.end();
  const timer = setTimeout(() => { failure = new Error(`${mode}: watchdog\n${output}`); child.kill("SIGKILL"); }, 10000);
  try {
    if (mode === "clean") {
      const [code, signal] = await closed;
      assert.equal(code, 0, output); assert.equal(signal, null);
      assert.equal(output.includes(notice), false);
    } else {
      const deadline = Date.now() + 8000;
      while (!output.includes(notice) && !ended && Date.now() < deadline)
        await new Promise(resolve => setTimeout(resolve, 20));
      assert.ok(output.includes(notice), output);
      const measure = () => execFileSync("ps", ["-o", "rss=", "-o", "time=", "-p", String(child.pid)], { encoding: "utf8" }).trim();
      const before = measure();
      await new Promise(resolve => setTimeout(resolve, 1500));
      assert.equal(ended, false, output);
      const after = measure();
      const [rssBefore, cpuBefore] = before.split(/\s+/);
      const [rssAfter, cpuAfter] = after.split(/\s+/);
      const seconds = value => value.split(":").reduce((sum, part) => sum * 60 + Number(part), 0);
      const cpuDelta = seconds(cpuAfter) - seconds(cpuBefore);
      assert.ok(cpuDelta >= 0 && cpuDelta <= 0.051, `Suspension exceeded idle CPU budget: ${cpuDelta}s`);
      assert.ok(Math.abs(Number(rssAfter) - Number(rssBefore)) <= 4096, "Suspension memory grew");
      assert.equal(output.split(notice).length - 1, 1);
      if (native) assert.equal(output.split("--- MarkBend multiline checkpoint ---").length - 1, mode === "pending" ? 0 : mode === "draft" ? 1 : 2);
      if (mode === "pending") assert.ok(output.includes("Pending state checked before input-ended dispatch"));
      assert.equal(output.split("Unsaved changes.").length - 1, mode === "choice_eof" && native ? 1 : 0);
      child.kill("SIGTERM"); await closed;
    }
    if (failure) throw failure;
    assert.deepEqual(fs.readFileSync(file), Buffer.from("A\r\n"));
    console.log(`Input suspension ${runtime} ${mode} passed`);
  } finally {
    clearTimeout(timer);
    if (!ended) { child.kill("SIGKILL"); await closed; }
    fs.rmSync(root, { recursive: true });
  }
}
