import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const [app] = process.argv.slice(2);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'markbend-save-as-native-'));
const directory = fs.realpathSync(root);
try {
  const original = path.join(directory, 'original.md');
  const target = path.join(directory, '中文 😀.md');
  const bytes = Buffer.from('\uFEFF中文😀\r\né\0\n');
  fs.writeFileSync(original, bytes);
  const env = { ...process.env, MARKBEND_OPEN_PATH: original, MARKBEND_SAVE_AS_TARGET: target };
  delete env.MARKBEND_STARTUP_RECOVERY_HOST; delete env.MARKBEND_STARTUP_RECOVERY_ROOT;
  const result = spawnSync(app, [], { env, encoding: 'utf8', timeout: 35000 });
  assert.ifError(result.error); assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /Native Save As button, Cancel, shortcut, dialog, and exact bytes passed/);
  assert.deepEqual(fs.readFileSync(original), bytes); assert.deepEqual(fs.readFileSync(target), bytes);
  assert.deepEqual(fs.readdirSync(directory).sort(), ['original.md', '中文 😀.md']);
  console.log(result.stdout.trim());
} finally { fs.rmSync(root, { recursive: true }); }
