import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const [app] = process.argv.slice(2);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'markbend-native-recheck-'));
const directory = fs.realpathSync(root);
const info = fs.statSync(directory, { bigint: true });
const key = `DIR1:${info.dev}:${info.ino}`;
const bytes = Buffer.from('\uFEFF中文😀\r\né\0\n');
try {
  for (const mode of ['exact', 'mismatch', 'missing']) {
    const target = path.join(directory, `${mode}.md`);
    const observed = mode === 'mismatch' ? Buffer.from('other') : bytes;
    if (mode !== 'missing') fs.writeFileSync(target, observed);
    const result = spawnSync(app, [target, key, mode === 'exact' ? 'confirmed' : 'retained'],
      { encoding: 'utf8', timeout: 30000 });
    assert.ifError(result.error); assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /Native workspace Recheck event and exact transaction check passed/);
    if (mode !== 'missing') assert.deepEqual(fs.readFileSync(target), observed);
    else assert.equal(fs.existsSync(target), false);
  }
  assert.deepEqual(fs.readdirSync(directory).sort(), ['exact.md', 'mismatch.md']);
  console.log('Native Save and Close guards, Recheck button, and retained disk bytes passed');
} finally { fs.rmSync(root, { recursive: true }); }
