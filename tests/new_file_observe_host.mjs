import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const [runtime, program] = process.argv.slice(2);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'markbend-observe-host-'));
const directory = fs.realpathSync(root);
const target = path.join(directory, '中文😀.md');
const info = fs.statSync(directory, { bigint: true });
const key = `DIR1:${info.dev}:${info.ino}`;
const bytes = Buffer.from([239,187,191,228,184,173,240,159,152,128,13,10,0]);
function run(mode, parent = key) {
  const result = spawnSync(runtime === 'native' ? program : runtime,
    runtime === 'native' ? [target, parent, mode] : [program, target, parent, mode],
    { encoding: 'utf8', timeout: 20000 });
  assert.ifError(result.error); assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /New-file observation effect passed/);
}
try {
  fs.writeFileSync(target, bytes);
  for (let i = 0; i < 4; i++) run(runtime === 'native' ? 'confirmed' : 'retained');
  for (const mode of ['bad-output', 'bad-identity', 'bad-parent', 'nul-path']) run(mode);
  run('retained', 'DIR1:0:0');
  assert.deepEqual(fs.readFileSync(target), bytes);
  fs.writeFileSync(target, 'different'); run('retained');
  assert.deepEqual(fs.readFileSync(target), Buffer.from('different'));
  fs.unlinkSync(target); run('retained');
  fs.symlinkSync('missing', target); run('retained'); assert.equal(fs.readlinkSync(target), 'missing');
  fs.unlinkSync(target); fs.mkdirSync(target); run('retained'); fs.rmdirSync(target);
  assert.deepEqual(fs.readdirSync(directory), []);
  console.log(`New-file observation ${runtime} effect checks passed without byte changes`);
} finally { fs.rmSync(root, { recursive: true }); }
