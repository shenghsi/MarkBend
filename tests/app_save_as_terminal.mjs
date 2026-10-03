import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const [app, failureApp] = process.argv.slice(2);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'markbend-app-save-as-'));
const directory = fs.realpathSync(root);
const original = path.join(directory, 'original.md');
const target = path.join(directory, '中文 😀.md');
const first = Buffer.from('\uFEFF中文😀\r\né\0\n');
const later = Buffer.from('later😀\n');
try {
  for (const untitled of [false, true]) {
    fs.writeFileSync(original, 'A\r\n');
    const env = { ...process.env };
    delete env.MARKBEND_STARTUP_RECOVERY_HOST; delete env.MARKBEND_STARTUP_RECOVERY_ROOT;
    if (untitled) delete env.MARKBEND_OPEN_PATH; else env.MARKBEND_OPEN_PATH = original;
    const input = Buffer.concat([first, Buffer.from(`.apply\n.saveas ${target}\n`), later,
      Buffer.from('.apply\n.save\n.close\n')]);
    const result = spawnSync(app, [], { input, env, encoding: 'utf8', timeout: 20000 });
    assert.ifError(result.error); assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(fs.readFileSync(original), Buffer.from('A\r\n'));
    assert.deepEqual(fs.readFileSync(target), later);
    assert.equal((result.stderr.match(/(?:^|> )Saved\n/gm) || []).length, 2, result.stderr);
    assert.deepEqual(fs.readdirSync(directory).sort(), ['original.md', '中文 😀.md']);
    fs.unlinkSync(target);
  }
  const env = { ...process.env, MARKBEND_OPEN_PATH: original };
  delete env.MARKBEND_STARTUP_RECOVERY_HOST; delete env.MARKBEND_STARTUP_RECOVERY_ROOT;
  fs.writeFileSync(target, 'occupied');
  const occupied = spawnSync(app, [], { env, encoding: 'utf8', timeout: 20000,
    input: Buffer.concat([first, Buffer.from(`.apply\n.saveas ${target}\n.close\n.discard\n`)]) });
  assert.ifError(occupied.error); assert.equal(occupied.status, 0, occupied.stderr);
  assert.match(occupied.stderr, /Save As stopped without overwriting a file:/);
  assert.deepEqual(fs.readFileSync(target), Buffer.from('occupied'));
  assert.deepEqual(fs.readFileSync(original), Buffer.from('A\r\n')); fs.unlinkSync(target);
  if (failureApp) for (const mode of ['old', 'conflict', 'uncertain']) {
    const blockedTarget = path.join(directory, 'blocked.md');
    const suffix = mode === 'uncertain'
      ? `.save\n.saveas ${blockedTarget}\n.close\n.undo\n.redo\n`
      : '.close\n.discard\n';
    const result = spawnSync(failureApp, [], { env: { ...env, MARKBEND_PUBLISH_FAILURE: mode },
      input: Buffer.concat([first, Buffer.from(`.apply\n.saveas ${target}\n${suffix}`)]),
      encoding: 'utf8', timeout: mode === 'uncertain' ? 3000 : 20000 });
    if (mode === 'uncertain') {
      assert.equal(result.error?.code, 'ETIMEDOUT', result.stderr);
      assert.equal((result.stderr.match(/Save As is pending or uncertain\. Keep this document open/g) || []).length, 3);
      assert.equal((result.stderr.match(/Input ended\. Unsaved document retained; resume is unavailable/g) || []).length, 1);
      assert.deepEqual(fs.readFileSync(target), first);
      assert.equal(fs.existsSync(blockedTarget), false);
      assert.equal((result.stderr.match(/Unsaved changes\./g) || []).length, 0);
      assert.equal((result.stderr.match(/(?:^|> )Saved\n/gm) || []).length, 0);
    } else {
      assert.ifError(result.error); assert.equal(result.status, 0, result.stderr);
      if (mode === 'old') assert.equal(fs.existsSync(target), false);
      else assert.deepEqual(fs.readFileSync(target), Buffer.from('occupied'));
    }
    assert.deepEqual(fs.readFileSync(original), Buffer.from('A\r\n'));
    assert.deepEqual(fs.readdirSync(directory).sort(), mode === 'old' ? ['original.md'] : ['original.md', '中文 😀.md']);
    if (fs.existsSync(target)) fs.unlinkSync(target);
  }
  if (failureApp) {
    for (const mode of ['uncertain-mismatch', 'uncertain-missing']) {
      const result = spawnSync(failureApp, [], { env: { ...env, MARKBEND_PUBLISH_FAILURE: mode },
        input: Buffer.concat([first, Buffer.from(`.apply\n.saveas ${target}\n.recheck\n.recheck\n.save\n.close\n`)]),
        encoding: 'utf8', timeout: 3000 });
      assert.equal(result.error?.code, 'ETIMEDOUT', result.stderr);
      assert.equal((result.stderr.match(/Save As is still uncertain\. Keep this document open/g) || []).length, 2);
      assert.equal((result.stderr.match(/Save As is pending or uncertain\. Keep this document open/g) || []).length, 2);
      assert.equal((result.stderr.match(/Input ended\. Unsaved document retained; resume is unavailable/g) || []).length, 1);
      assert.equal((result.stderr.match(/Save As confirmed/g) || []).length, 0);
      assert.deepEqual(fs.readFileSync(original), Buffer.from('A\r\n'));
      if (mode === 'uncertain-mismatch') {
        assert.deepEqual(fs.readFileSync(target), Buffer.from('other'));
        assert.deepEqual(fs.readdirSync(directory).sort(), ['original.md', '中文 😀.md']);
        fs.unlinkSync(target);
      } else {
        assert.equal(fs.existsSync(target), false);
        assert.deepEqual(fs.readdirSync(directory), ['original.md']);
      }
    }
    const input = Buffer.concat([first, Buffer.from(`.apply\n.saveas ${target}\n.save\n.close\n.recheck\n.recheck\n`),
      later, Buffer.from('.apply\n.save\n.close\n')]);
    const result = spawnSync(failureApp, [], { env: { ...env, MARKBEND_PUBLISH_FAILURE: 'uncertain' },
      input, encoding: 'utf8', timeout: 20000 });
    assert.ifError(result.error); assert.equal(result.status, 0, result.stderr);
    assert.equal((result.stderr.match(/Save As is pending or uncertain\. Keep this document open/g) || []).length, 2);
    assert.equal((result.stderr.match(/Save As confirmed/g) || []).length, 1);
    assert.equal((result.stderr.match(/No uncertain Save As to recheck/g) || []).length, 1);
    assert.deepEqual(fs.readFileSync(target), later);
    assert.deepEqual(fs.readFileSync(original), Buffer.from('A\r\n'));
    assert.deepEqual(fs.readdirSync(directory).sort(), ['original.md', '中文 😀.md']);
  }
  console.log('Terminal app Save As, failure retention, Recheck adoption, and later Save passed');
} finally { fs.rmSync(root, { recursive: true }); }
