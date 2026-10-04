import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

for (const args of [[resolve('src/web/build-bend.mjs')], [resolve('node_modules/vitest/vitest.mjs'), 'run', 'tests/performance/editor.test.ts']]) {
  const result = spawnSync(process.execPath, args, { stdio: 'inherit', env: { ...process.env, MARKBEND_BENCH: '1' } });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
