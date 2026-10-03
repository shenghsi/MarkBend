import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const [runtime, program] = process.argv.slice(2);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'markbend-observe-driver-'));
const directory = fs.realpathSync(root);
const info = fs.statSync(directory, { bigint: true });
const key = `DIR1:${info.dev}:${info.ino}`;
const bytes = Buffer.from('\uFEFF中文😀\r\né\0\n');
try {
  for (const mode of ['exact', 'mismatch', 'missing', 'wrong-parent']) {
    const target = path.join(directory, `${mode}.md`);
    const observed = mode === 'mismatch' ? Buffer.from('other') : bytes;
    if (mode !== 'missing') fs.writeFileSync(target, observed);
    const parent = mode === 'wrong-parent' ? 'DIR1:0:0' : key;
    const expected = mode === 'exact' && runtime === 'native' ? 'confirmed' : 'retained';
    const result = spawnSync(runtime === 'native' ? program : runtime,
      runtime === 'native' ? [target, parent, expected] : [program, target, parent, expected],
      { encoding: 'utf8', timeout: 20000 });
    assert.ifError(result.error); assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stdout, /New-file observation driver adoption and retained transaction passed/);
    if (mode !== 'missing') assert.deepEqual(fs.readFileSync(target), observed);
    else assert.equal(fs.existsSync(target), false);
  }
  assert.deepEqual(fs.readdirSync(directory).sort(), ['exact.md', 'mismatch.md', 'wrong-parent.md']);
  console.log(`Observation driver ${runtime} confirmed adoption or retained exact transaction`);
} finally { fs.rmSync(root, { recursive: true }); }
