import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const [runtime, program, failureProgram] = process.argv.slice(2);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'markbend-publish-driver-'));
const directory = fs.realpathSync(root);
const bytes = Buffer.from('\uFEFF中文😀\r\né\0\n');
try {
  for (const mode of runtime === 'native' ? ['save', 'old', 'uncertain', 'conflict'] : ['unavailable', 'publication-unavailable']) {
    const target = path.join(directory, `${mode}.md`);
    const executable = runtime === 'native' ? (mode === 'save' ? program : failureProgram) : runtime;
    const args = runtime === 'native' ? [target, mode] : [program, target, mode];
    const result = spawnSync(executable, args, { encoding: 'utf8', timeout: 20000,
      env: { ...process.env, MARKBEND_PUBLISH_FAILURE: mode } });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /New-file publication driver completion passed/);
    if (mode === 'save' || mode === 'uncertain') assert.deepEqual(fs.readFileSync(target), bytes);
    else if (mode === 'conflict') assert.deepEqual(fs.readFileSync(target), Buffer.from('occupied'));
    else assert.equal(fs.existsSync(target), false);
  }
  assert.deepEqual(fs.readdirSync(directory).sort(), runtime === 'native' ? ['conflict.md', 'save.md', 'uncertain.md'] : []);
  console.log(`New-file driver ${runtime} destination, history, and failure checks passed`);
} finally { fs.rmSync(root, { recursive: true }); }
