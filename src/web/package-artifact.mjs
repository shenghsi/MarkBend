import { createHash } from 'node:crypto';
import { copyFileSync, lstatSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

// Record build artifacts only. This command does not sign, install, or publish.
const kind = process.argv[2];
const formats = { app: ['desktop-package', '.zip'], deb: ['src/desktop/target/release/bundle/deb', '.deb'], nsis: ['src/desktop/target/release/bundle/nsis', '.exe'] };
if (!Object.hasOwn(formats, kind)) throw new Error('Expected app, deb, or nsis');
const sha = process.env.CI_CHECKOUT_SHA;
if (!/^[a-f0-9]{40}$/.test(sha ?? '')) throw new Error('Expected complete checkout SHA');
const [folder, suffix] = formats[kind];
const files = readdirSync(folder).filter(name => name.endsWith(suffix)).sort();
if (!files.length) throw new Error('No package produced');
if (files.length !== 1) throw new Error('Expected exactly one package');
let signing = 'unsigned';
if (kind === 'app') {
  const app = 'src/desktop/target/release/bundle/macos/MarkBend.app';
  const verify = spawnSync('codesign', ['--verify', '--deep', '--strict', app], { encoding: 'utf8' });
  const describe = spawnSync('codesign', ['--display', '--verbose=4', app], { encoding: 'utf8' });
  if (verify.status !== 0 || describe.status !== 0 || !/Signature=adhoc/.test(describe.stderr))
    throw new Error('Expected a verified ad-hoc macOS app');
  signing = 'ad-hoc';
}
mkdirSync('desktop-package', { recursive: true });
const packages = files.map(name => {
  const source = join(folder, name);
  if (!lstatSync(source).isFile()) throw new Error('Package must be a regular file');
  const bytes = readFileSync(source);
  if (!bytes.length) throw new Error('Empty package');
  if (kind !== 'app') copyFileSync(source, join('desktop-package', name));
  return { name, bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') };
});
writeFileSync('desktop-package/manifest.json', JSON.stringify({ schema: 1, checkout: sha,
  os: process.env.RUNNER_OS ?? process.platform, arch: process.env.RUNNER_ARCH ?? process.arch,
  format: kind, unsigned: true, signing, packages }, null, 2) + '\n');
