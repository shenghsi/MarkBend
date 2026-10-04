import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const preview = process.argv.includes('--preview');
for (const args of [[resolve('src/web/build-bend.mjs')], [resolve('node_modules/vitest/vitest.mjs'), 'run', 'tests/performance/editor.test.ts']]) {
  const result = spawnSync(process.execPath, args, { stdio: 'inherit', env: { ...process.env,
    MARKBEND_BENCH: preview ? '0' : '1', MARKBEND_PREVIEW_BENCH: preview ? '1' : '0' } });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
