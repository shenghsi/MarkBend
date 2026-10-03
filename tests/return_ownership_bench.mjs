import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const [app, variant, ...options] = process.argv.slice(2);
assert.ok(app, 'Supply the native ownership benchmark');
assert.ok(options.every(option => option === '--memory'), 'Unknown option');
const memory = options.includes('--memory');
assert.ok(!memory || ['darwin', 'linux'].includes(process.platform),
  'Process memory measurement requires macOS or Linux');
const runs = variant
  ? [['control', app, 'original'], ['variant', variant, 'original'],
    ['variant', variant, 'original'], ['control', app, 'original'],
    ['variant', variant, 'undo'], ['control', app, 'undo'],
    ['control', app, 'undo'], ['variant', variant, 'undo']]
  : ['original', 'undo', 'undo', 'original'].map(mode => ['control', app, mode]);
console.log('Diagnostic ownership control; four threads; 20 samples per process; millisecond clock.');
for (const [run, [build, binary, mode]] of runs.entries()) {
  const args = ['--threads', '4', mode];
  const result = spawnSync(memory ? '/usr/bin/time' : binary,
    memory ? [process.platform === 'darwin' ? '-l' : '-v', binary, ...args] : args, {
    encoding: 'utf8', timeout: 600000,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const expression = mode === 'original'
    ? /^core_return size=65538 sample=(\d+) elapsed_ms=(\d+)$/
    : /^undo_return sample=(\d+) elapsed_ms=(\d+)$/;
  const times = [];
  for (const line of result.stdout.split('\n')) {
    const match = expression.exec(line);
    if (!match) continue;
    assert.equal(Number(match[1]), times.length + 1);
    times.push(Number(match[2]));
  }
  assert.equal(times.length, 20);
  assert.ok(result.stdout.includes(mode === 'original'
    ? 'Core Return command samples passed size=65538'
    : 'Undo baseline Return samples passed'));
  const sorted = [...times].sort((a, b) => a - b);
  let peak = '';
  if (memory) {
    const match = process.platform === 'darwin'
      ? /^\s*(\d+)\s+maximum resident set size\s*$/m.exec(result.stderr)
      : /^\s*Maximum resident set size \(kbytes\):\s*(\d+)\s*$/m.exec(result.stderr);
    assert.ok(match, 'Missing peak resident memory');
    peak = ` peak_rss_bytes=${Number(match[1]) * (process.platform === 'linux' ? 1024 : 1)}`;
  }
  console.log(`run=${run + 1} build=${build} mode=${mode} sample_ms=${times.join(',')} median_ms=${(sorted[9] + sorted[10]) / 2}${peak}`);
}
console.log('All ownership checks passed. This control does not measure native frames.');
