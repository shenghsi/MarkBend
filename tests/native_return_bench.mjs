import assert from 'node:assert/strict';
import os from 'node:os';
import { spawnSync } from 'node:child_process';

const [app] = process.argv.slice(2);
assert.ok(app, 'Supply the native Return benchmark binary');
const version = spawnSync('bend', ['version'], { encoding: 'utf8' });
assert.ifError(version.error);
assert.equal(version.status, 0, version.stdout + version.stderr);
console.log(`Native Return layout and display: ${version.stdout.trim()}, four threads, ${os.platform()} ${os.release()}, ${os.machine()}, ${os.cpus()[0]?.model}, ${os.totalmem()} memory bytes`);
for (const stages of [false, true]) {
  for (const fixture of ['small', 'large', 'long']) {
    const args = ['--threads', '4', fixture, ...(stages ? ['stages'] : [])];
    const result = spawnSync(app, args, { encoding: 'utf8', timeout: 600000 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const size = { small: 102400, large: 1048576, long: 65538 }[fixture];
    assert.ok(result.stdout.includes(`Native Return fixture bytes=${size} stages=${Number(stages)}`));
    assert.equal([...result.stdout.matchAll(/^native_return_surface /gm)].length, 1);
    const records = [...result.stdout.matchAll(/^native_return sample=(\d+) elapsed_ms=([\d.]+) drawing_ms=([\d.]+)$/gm)];
    assert.equal(records.length, 20, result.stdout);
    assert.ok(result.stdout.includes('Native Return layout and display samples passed'));
    records.forEach((r, i) => assert.equal(Number(r[1]), i + 1));
    const stageRecords = [...result.stdout.matchAll(/^native_return_stage sample=(\d+) /gm)];
    assert.equal(stageRecords.length, stages ? 20 : 0);
    stageRecords.forEach((r, i) => assert.equal(Number(r[1]), i + 1));
    const patchRecords = [...result.stdout.matchAll(/^native_return_patch sample=(\d+) comparison_ms=([\d.]+) storage_ms=([\d.]+) removed=(\d+) inserted=(\d+) maximum=(\d+) count=(\d+)$/gm)];
    assert.equal(patchRecords.length, stages ? 20 : 0);
    const ranges = [...result.stdout.matchAll(/^native_return_patch_range sample=(\d+) patch=(\d+) start=(\d+) removed=(\d+) inserted=(\d+)$/gm)];
    patchRecords.forEach((record, index) => {
      assert.equal(Number(record[1]), index + 1);
      assert.ok(Number.isFinite(Number(record[2])) && Number(record[2]) >= 0);
      assert.ok(Number.isFinite(Number(record[3])) && Number(record[3]) >= 0);
      const sampleRanges = ranges.filter(range => range[1] === record[1]);
      assert.equal(sampleRanges.length, Number(record[7]));
      assert.ok(sampleRanges.length > 0, 'Return must change the preview');
      sampleRanges.forEach((range, i) => assert.equal(Number(range[2]), i + 1));
      assert.equal(Math.max(...sampleRanges.flatMap(range => [Number(range[4]), Number(range[5])])), Number(record[6]));
      assert.equal(Number(sampleRanges.at(-1)[4]), Number(record[4]));
      assert.equal(Number(sampleRanges.at(-1)[5]), Number(record[5]));
    });
    assert.equal(ranges.length, patchRecords.reduce((count, record) => count + Number(record[7]), 0));
    const times = records.map(r => Number(r[2]));
    assert.ok(times.every(t => Number.isFinite(t) && t >= 0));
    const sorted = [...times].sort((a, b) => a - b);
    console.log(`fixture=${fixture} instrumented=${stages} median_ms=${((sorted[9] + sorted[10]) / 2).toFixed(3)} p95_nearest_rank_ms=${sorted[18].toFixed(3)} sample_ms=${times.join(',')}`);
    process.stdout.write(result.stdout);
  }
}
console.log('All six native Return batches passed. Display completion does not measure physical screen presentation. The p95 estimate uses only 20 samples.');
