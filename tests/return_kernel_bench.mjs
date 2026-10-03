import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const [app] = process.argv.slice(2);
assert.ok(app, 'Supply the native Return kernel benchmark');
const result = spawnSync(app, ['--threads', '4'], {
  encoding: 'utf8', timeout: 600000,
});
assert.ifError(result.error);
assert.equal(result.status, 0, result.stdout + result.stderr);
const samples = new Map([['document', []], ['scene', []]]);
for (const line of result.stdout.split('\n')) {
  const match = /^return_kernel kind=(document|scene) sample=(\d+) elapsed_ms=(\d+)$/.exec(line);
  if (!match) continue;
  const times = samples.get(match[1]);
  assert.equal(Number(match[2]), times.length + 1);
  times.push(Number(match[3]));
}
for (const [kind, times] of samples) {
  assert.equal(times.length, 20);
  assert.ok(result.stdout.includes(`${kind === 'document' ? 'Document' : 'Scene'} Return kernel checks passed`));
  const sorted = [...times].sort((a, b) => a - b);
  console.log(`kind=${kind} sample_ms=${times.join(',')} median_ms=${(sorted[9] + sorted[10]) / 2}`);
}
console.log('All 40 kernel checks passed. Diagnostic forcing and ownership differ; do not add these times.');
