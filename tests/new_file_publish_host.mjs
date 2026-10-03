import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const [runtime, program] = process.argv.slice(2);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'markbend-publish-host-'));
const directory = fs.realpathSync(root);
const info = fs.statSync(directory, { bigint: true });
const parent = `DIR1:${info.dev}:${info.ino}`;
const bytes = Buffer.from([239,187,191,228,184,173,240,159,152,128,13,10,0]);
function run(leaf, mode) {
  const target = path.join(directory, leaf);
  const args = runtime === 'native' ? [target, parent, mode] : [program, target, parent, mode];
  const result = spawnSync(runtime === 'native' ? program : runtime, args,
    { encoding: 'utf8', timeout: 20000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr + result.stdout);
  assert.match(result.stdout, /New-file publication host result passed/);
  return target;
}
try {
  if (runtime === 'native') {
    const target = run('中文😀.md', 'save');
    assert.deepEqual(fs.readFileSync(target), bytes);
    assert.equal(fs.statSync(target).mode & 0o777, 0o600);
    run('中文😀.md', 'conflict');
    assert.deepEqual(fs.readFileSync(target), bytes);
    for (const mode of ['bad-identity', 'bad-parent', 'bad-output']) {
      const rejected = run(`${mode}.md`, mode);
      assert.equal(fs.existsSync(rejected), false);
    }
    assert.deepEqual(fs.readdirSync(directory), ['中文😀.md']);
  } else {
    const target = run('unavailable.md', 'unavailable');
    assert.equal(fs.existsSync(target), false);
    assert.deepEqual(fs.readdirSync(directory), []);
  }
  console.log(`New-file publication ${runtime} effect bytes and rejection checks passed`);
} finally {
  fs.rmSync(root, { recursive: true });
}
