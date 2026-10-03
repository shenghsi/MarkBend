import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import assert from "node:assert/strict";

const source = readFileSync(new URL("../src/document_file.js", import.meta.url), "utf8")
  .replace(/CID\(([^)]+)\)/g, '"$1"');
function run(options = {}) {
  let read;
  let offset = 0;
  let opened = 0;
  let closed = 0;
  let reads = 0;
  const bytes = Buffer.from([239, 187, 191, 65, 0, 255]);
  const resolved = Buffer.from([47, 98, 97, 100, 45, 255]);
  const stat = { size: options.over ? 8388609n : 6n, dev: 1n, ino: 2n,
    isFile: () => !options.directory };
  const fs = {
    constants: { O_RDONLY: 0, O_NONBLOCK: 4, O_NOFOLLOW: options.missingFlags ? undefined : 8, O_CLOEXEC: 16 },
    realpathSync: { native: () => resolved },
    openSync: (path, flags) => {
      assert.deepEqual(path, resolved); assert.equal(flags, 28);
      if (options.openFailure) throw { errno: -13, message: "open failed" };
      opened++; return 7;
    },
    fstatSync: (fd) => { assert.equal(fd, 7); return stat; },
    readSync: (fd, target, start, amount, position) => {
      assert.equal(fd, 7); assert.equal(position, null); reads++;
      if (options.interrupted && reads === 1) throw { code: "EINTR" };
      if (options.readFailure) throw { errno: -5, message: "read failed" };
      if (options.afterPrefix && reads === 3) throw { errno: -5, message: "prefix read failed" };
      if (options.aggregateOverflow) {
        target.fill(0, start, start + amount); offset += amount; return amount;
      }
      const count = Math.min(2, amount, bytes.length - offset);
      bytes.copy(target, start, offset, offset + count); offset += count; return count;
    },
    lstatSync: () => ({ ...stat, ino: options.replaced ? 3n : 2n }),
    closeSync: (fd) => {
      assert.equal(fd, 7); closed++;
      if (options.closeFailure) throw { errno: -5, message: "close failed" };
    }
  };
  const context = { Buffer, io_eff: (_, fn) => { read = fn; },
    io_tup: (...values) => values, io_done: value => ({ $: "Done", value }) };
  if (!options.browser) context.require = name => { assert.equal(name, "node:fs"); return fs; };
  runInNewContext(source, context);
  const result = read(options.path ?? "alias");
  assert.equal(closed, opened);
  return { result, bytes, resolved, opened, reads };
}
function unlist(cell) {
  const bytes = [];
  while (cell.$ !== "Nil") { bytes.push(cell.head); cell = cell.tail; }
  return Buffer.from(bytes);
}
for (const interrupted of [false, true]) {
  const value = run({ interrupted });
  assert.equal(value.result.$, "Done");
  const [path, [identity, bytes]] = value.result.value;
  assert.deepEqual(unlist(path), value.resolved);
  assert.deepEqual(unlist(identity), Buffer.concat([Buffer.from("PATH1:"), value.resolved]));
  assert.deepEqual(unlist(bytes), value.bytes);
  assert.equal(value.reads, interrupted ? 5 : 4);
}
for (const options of [{ replaced: true }, { readFailure: true }, { closeFailure: true },
  { afterPrefix: true }, { aggregateOverflow: true }, { openFailure: true }, { missingFlags: true },
  { directory: true }, { over: true }, { browser: true }, { path: "a\0b" },
  { path: "\ud800" }, { path: "\udc00" }]) {
  assert.equal(run(options).result.$, "Fail");
}
assert.equal(run({ readFailure: true, closeFailure: true }).result.error[1], "read failed");
console.log("JavaScript resolved-file short reads, failures, replacement, and closure passed");
