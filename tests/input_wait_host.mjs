import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import path from "node:path";

async function run(mode, executable) {
  const child = spawn(path.resolve(executable), [mode], {
    stdio: ["ignore", "pipe", "pipe", "pipe", "pipe"],
  });
  let notices = Buffer.alloc(0), output = "", errorOutput = "", first, count = 0, failure;
  const timer = setTimeout(() => {
    failure = new Error(`${mode}: wake timeout; ${output}; ${errorOutput}`);
    child.kill("SIGTERM");
  }, 10000);
  child.stdout.on("data", bytes => { output += bytes.toString(); });
  child.stderr.on("data", bytes => { errorOutput += bytes.toString(); });
  child.stdio[3].on("error", error => {
    if (!["EPIPE", "ECONNRESET"].includes(error.code)) failure = error;
  });
  child.stdio[4].on("error", error => {
    if (error.code !== "ECONNRESET") failure = error;
  });
  child.stdio[4].on("data", bytes => {
    notices = Buffer.concat([notices, bytes]);
    try {
      while (notices.length >= 20) {
        const challenge = Buffer.from(notices.subarray(0, 20));
        notices = notices.subarray(20);
        assert.equal(challenge.subarray(0, 4).toString(), "MBW1");
        count++;
        if (first) assert.notDeepEqual(challenge, first);
        else first = challenge;
        if (mode === "eof") child.stdio[3].end();
        else if (mode === "bad") {
          challenge[19] ^= 1; child.stdio[3].write(challenge);
        } else if (mode === "old" && count === 2) child.stdio[3].write(first);
        else if (mode === "extra") child.stdio[3].write(Buffer.concat([challenge, Buffer.from([1])]));
        else if (mode === "partial") {
          child.stdio[3].write(challenge.subarray(0, 3));
          setImmediate(() => child.stdio[3].write(challenge.subarray(3)));
        } else child.stdio[3].write(challenge);
      }
    } catch (error) { failure = error; child.kill("SIGTERM"); }
  });
  try {
    const [code, signal] = await new Promise((resolve, reject) => {
      child.on("error", reject);
      child.on("close", (code, signal) => resolve([code, signal]));
    });
    if (failure) throw failure;
    assert.equal(code, 0, `${mode}: ${errorOutput}`);
    assert.equal(signal, null);
    assert.equal(notices.length, 0);
    assert.equal(count, ["repeat", "old"].includes(mode) ? 2 : 1);
    assert.ok(output.includes("Private wake retained the complete document across host waits"));
    console.log(`Private wake ${mode} passed`);
  } finally { clearTimeout(timer); }
}
for (const mode of ["resume", "partial", "repeat", "old", "extra", "bad", "eof"])
  await run(mode, process.argv[2]);
