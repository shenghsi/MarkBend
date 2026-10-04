import { mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
mkdirSync('src/web/generated', { recursive: true });
const result = spawnSync(process.env.BEND_BIN || 'bend',
  ['src/WebCommands.bend', '-o', 'src/web/generated/commands.mjs'], { stdio: 'inherit' });
if (result.error) throw result.error;
process.exit(result.status ?? 1);
