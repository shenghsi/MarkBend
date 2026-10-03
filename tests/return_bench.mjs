import assert from 'node:assert/strict';
import os from 'node:os';
import { spawnSync } from 'node:child_process';

const [app] = process.argv.slice(2);
assert.ok(app, 'Supply the native Return benchmark binary');
const version = spawnSync('bend', ['version'], { encoding: 'utf8' });
assert.ifError(version.error);
assert.equal(version.status, 0, version.stdout + version.stderr);
const result = spawnSync(app, ['--threads', '4'], { encoding: 'utf8', timeout: 600000 });
assert.ifError(result.error);
assert.equal(result.status, 0, result.stdout + result.stderr);
const records = new Map([[102400, []], [1048576, []], [65538, []]]);
for (const line of result.stdout.split('\n')) {
  const match = /^core_return size=(\d+) sample=(\d+) elapsed_ms=(\d+)$/.exec(line);
  if (!match) continue;
  const [, rawSize, rawSample, rawTime] = match;
  const times = records.get(Number(rawSize));
  assert.ok(times, line);
  assert.equal(Number(rawSample), times.length + 1, line);
  times.push(Number(rawTime));
}
console.log(`Core Return command: ${version.stdout.trim() || version.stderr.trim()}, native, four threads, ${os.platform()} ${os.release()}, ${os.machine()}, ${os.cpus()[0]?.model}, ${os.totalmem()} memory bytes`);
console.log('Normal native build: bend tests/ReturnCommandBench.bend -o <binary>');
console.log('IO.now millisecond clock; cached source/byte/scene counts and dirty state are forced inside each interval.');
console.log('Load, initial selection, exact source, baseline, view, undo, and redo checks are outside the interval.');
for (const [size, times] of records) {
  assert.equal(times.length, 20, `Missing samples for ${size} bytes`);
  assert.ok(result.stdout.includes(`Core Return baseline preflight passed size=${size}`));
  assert.ok(result.stdout.includes(`Core Return command samples passed size=${size}`));
  const sorted = [...times].sort((a, b) => a - b);
  const median = (sorted[9] + sorted[10]) / 2;
  console.log(`size_bytes=${size} sample_ms=${times.join(',')} sum_ms=${times.reduce((a, b) => a + b, 0)} median_ms=${median}`);
}
console.log('This measures the core command. It does not measure a native frame or establish the 16 ms target.');
