import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const preview = process.argv.includes('--preview');
const unicode = process.argv.includes('--unicode');
const prose = process.argv.includes('--prose');
const offsets = process.argv.includes('--offsets');
const growth = process.argv.includes('--growth');
for (const args of [[resolve('src/web/build-bend.mjs')], [resolve('node_modules/vitest/vitest.mjs'), 'run', growth ? 'tests/performance/preview-growth.test.ts' : offsets ? 'tests/performance/offsets.test.ts' : 'tests/performance/editor.test.ts']]) {
  const result = spawnSync(process.execPath, args, { stdio: 'inherit', env: { ...process.env,
    MARKBEND_BENCH: preview || unicode || prose || offsets || growth ? '0' : '1', MARKBEND_PREVIEW_BENCH: preview ? '1' : '0',
    MARKBEND_GROWTH_BENCH: growth ? '1' : '0',
    MARKBEND_OFFSET_BENCH: offsets ? '1' : '0',
    MARKBEND_PROSE_BENCH: prose ? '1' : '0',
    MARKBEND_UNICODE_BENCH: unicode ? '1' : '0' } });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
