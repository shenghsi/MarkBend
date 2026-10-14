import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { collect, validateTag } from '../../src/release/release.mjs';

const sha = 'a'.repeat(40), tag = 'v0.1.0-beta.1';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'markbend-release-')), input = join(root, 'release-input'); mkdirSync(input);
  for (const [os, arch, format, signing, suffix] of [
    ['macOS', 'ARM64', 'app', 'ad-hoc', '.zip'], ['macOS', 'X64', 'app', 'ad-hoc', '.zip'],
    ['Linux', 'X64', 'deb', 'unsigned', '.deb'], ['Windows', 'X64', 'nsis', 'unsigned', '.exe'],
  ]) {
    const folder = join(input, `${os}-${arch}`); mkdirSync(folder);
    const name = 'MarkBend' + suffix, bytes = Buffer.from(`${os}-${arch} package`); writeFileSync(join(folder, name), bytes);
    writeFileSync(join(folder, 'manifest.json'), JSON.stringify({ schema: 1, checkout: sha, os, arch, format, signing,
      unsigned: true, packages: [{ name, bytes: bytes.length, sha256: hash(bytes) }] }));
  }
  return { root, input, output: join(root, 'output') };
}
test('beta tags require matching versions and reject unsafe or stable names', () => {
  assert.equal(validateTag(tag, ['0.1.0', '0.1.0', '0.1.0']), '0.1.0');
  for (const value of ['v0.1.0', 'v0.1.0-beta.0', 'v0.1.0-beta.01', 'v01.1.0-beta.1', 'v0.1.0-beta.1;echo bad', undefined])
    assert.throws(() => validateTag(value, ['0.1.0']));
  assert.throws(() => validateTag(tag, ['0.1.0', '0.2.0']));
});
test('four-platform collection produces unique packages and verifiable checksum entries', () => {
  const f = fixture();
  try {
    const assets = collect(f.input, f.output, tag, sha); assert.equal(assets.length, 9);
    const sums = readFileSync(join(f.output, 'SHA256SUMS'), 'utf8').trim().split('\n'); assert.equal(sums.length, 8);
    for (const entry of sums) { const [digest, name] = entry.split('  '); assert.equal(hash(readFileSync(join(f.output, name))), digest); }
    assert.ok(assets.some(path => path.endsWith('macos-arm64.zip'))); assert.ok(assets.some(path => path.endsWith('macos-x64.zip')));
    assert.throws(() => collect(f.input, f.output, tag, sha));
  } finally { rmSync(f.root, { recursive: true }); }
});
for (const fault of ['missing', 'changed', 'duplicate', 'checkout', 'signing', 'unexpected', 'traversal', 'empty']) {
  test(`rejects ${fault} artifacts before creating release output`, () => {
    const f = fixture();
    try {
      const folder = join(f.input, 'Linux-X64'), manifestPath = join(folder, 'manifest.json');
      const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
      if (fault === 'missing') rmSync(folder, { recursive: true });
      else if (fault === 'changed') writeFileSync(join(folder, 'MarkBend.deb'), 'changed');
      else if (fault === 'unexpected') writeFileSync(join(folder, 'extra'), 'extra');
      else {
        if (fault === 'duplicate') { manifest.os = 'macOS'; manifest.arch = 'X64'; }
        if (fault === 'checkout') manifest.checkout = 'b'.repeat(40);
        if (fault === 'signing') manifest.signing = 'Developer ID';
        if (fault === 'traversal') manifest.packages[0].name = '../outside.deb';
        if (fault === 'empty') { writeFileSync(join(folder, 'MarkBend.deb'), ''); manifest.packages[0].bytes = 0; manifest.packages[0].sha256 = hash(''); }
        writeFileSync(manifestPath, JSON.stringify(manifest));
      }
      assert.throws(() => collect(f.input, f.output, tag, sha));
      assert.throws(() => readFileSync(join(f.output, 'SHA256SUMS')));
    } finally { rmSync(f.root, { recursive: true }); }
  });
}
test('linked package files are rejected', { skip: process.platform === 'win32' }, () => {
  const f = fixture();
  try {
    const path = join(f.input, 'Linux-X64', 'MarkBend.deb'), bytes = readFileSync(path);
    writeFileSync(join(f.root, 'actual.deb'), bytes); rmSync(path); symlinkSync(join(f.root, 'actual.deb'), path);
    assert.throws(() => collect(f.input, f.output, tag, sha));
  } finally { rmSync(f.root, { recursive: true }); }
});

const program = fileURLToPath(new URL('../../src/release/release.mjs', import.meta.url));
function checkout(f) {
  mkdirSync(join(f.root, 'src/desktop'), { recursive: true });
  writeFileSync(join(f.root, 'package.json'), JSON.stringify({ version: '0.1.0' }));
  writeFileSync(join(f.root, 'package-lock.json'), JSON.stringify({ version: '0.1.0', packages: { '': { version: '0.1.0' } } }));
  writeFileSync(join(f.root, 'src/desktop/tauri.conf.json'), JSON.stringify({ version: '0.1.0' }));
  writeFileSync(join(f.root, 'src/desktop/Cargo.toml'), '[package]\nname="markbend-desktop"\nversion="0.1.0"\n');
  writeFileSync(join(f.root, 'BETA_RELEASE.md'), 'Test build. Native acceptance remains open.\n');
  const git = (...args) => {
    const result = spawnSync('git', args, { cwd: f.root, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr); return result.stdout.trim();
  };
  git('init', '-q'); git('add', 'package.json', 'package-lock.json', 'src/desktop', 'BETA_RELEASE.md');
  git('-c', 'user.name=Release test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Fixture');
  const checkoutSha = git('rev-parse', 'HEAD'); git('tag', tag);
  for (const platform of ['macOS-ARM64', 'macOS-X64', 'Linux-X64', 'Windows-X64']) {
    const path = join(f.input, platform, 'manifest.json'), manifest = JSON.parse(readFileSync(path));
    manifest.checkout = checkoutSha; writeFileSync(path, JSON.stringify(manifest));
  }
  const run = (mode, extra = {}) => spawnSync(process.execPath, [program, mode], { cwd: f.root, encoding: 'utf8',
    env: { ...process.env, RELEASE_TAG: tag, CI_CHECKOUT_SHA: checkoutSha, GH_REPO: 'example/MarkBend', ...extra } });
  return { run, checkoutSha };
}
test('CLI validates source versions and exact tag checkout before any release command', () => {
  const f = fixture();
  try {
    const { run } = checkout(f); assert.equal(run('validate').status, 0);
    assert.notEqual(run('validate', { CI_CHECKOUT_SHA: sha }).status, 0);
    assert.notEqual(run('validate', { RELEASE_TAG: 'v0.1.0-beta.2' }).status, 0);
    writeFileSync(join(f.root, 'src/desktop/tauri.conf.json'), JSON.stringify({ version: '0.2.0' }));
    assert.notEqual(run('validate').status, 0);
  } finally { rmSync(f.root, { recursive: true }); }
});
for (const state of ['success', 'existing', 'offline', 'upload-failed', 'missing-assets', 'wrong-state', 'wrong-digest']) {
  test(`draft creation handles ${state} without publishing or overwriting`, { skip: process.platform === 'win32' }, () => {
    const f = fixture();
    try {
      const { run } = checkout(f), bin = join(f.root, 'bin'); mkdirSync(bin);
      // A local fake CLI records writes. This test cannot contact GitHub.
      writeFileSync(join(bin, 'gh'), `#!/usr/bin/env node
const fs=require('node:fs'),args=process.argv.slice(2);fs.appendFileSync('calls.jsonl',JSON.stringify(args)+'\\n');
if(args[1]==='view'&&args.includes('--json')){let assets=fs.readdirSync('release-output').map(name=>{const bytes=fs.readFileSync('release-output/'+name);return {name,size:bytes.length,state:'uploaded',digest:'sha256:'+require('node:crypto').createHash('sha256').update(bytes).digest('hex')};});if(process.env.TEST_STATE==='missing-assets')assets.pop();if(process.env.TEST_STATE==='wrong-digest')assets[0].digest='sha256:bad';console.log(JSON.stringify({tagName:args[2],isDraft:process.env.TEST_STATE!=='wrong-state',isPrerelease:true,assets}));process.exit(0);}
if(args[1]==='view'){if(process.env.TEST_STATE==='existing')process.exit(0);console.error(process.env.TEST_STATE==='offline'?'network unavailable':'release not found');process.exit(1);}
if(args[1]==='create'&&process.env.TEST_STATE==='upload-failed'){console.error('upload failed');process.exit(1);}
`, { mode: 0o755 });
      const result = run('create', { PATH: `${bin}:${process.env.PATH}`, TEST_STATE: state });
      const calls = readFileSync(join(f.root, 'calls.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
      if (state === 'success') {
        assert.equal(result.status, 0, result.stderr); assert.equal(calls.length, 4);
        const create = calls[1]; for (const flag of ['--draft', '--prerelease', '--verify-tag', '--latest=false']) assert.ok(create.includes(flag));
        assert.equal(create.filter(arg => arg.startsWith('release-output/')).length, 9);
        assert.equal(calls[2][1], 'view'); assert.equal(calls[3][1], 'edit'); assert.ok(calls[3].includes('release-notes.md'));
      } else {
        assert.notEqual(result.status, 0); assert.equal(calls.length, state === 'upload-failed' ? 2 : ['existing','offline'].includes(state) ? 1 : 3);
        if (!['existing','offline'].includes(state)) assert.match(readFileSync(join(f.root, 'release-incomplete.md'), 'utf8'), /INCOMPLETE DRAFT/);
      }
      for (const args of calls) { assert.ok(!args.includes('--clobber')); assert.ok(!args.includes('--draft=false')); }
    } finally { rmSync(f.root, { recursive: true }); }
  });
}
