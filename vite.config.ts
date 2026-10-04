import { configDefaults, defineConfig } from 'vitest/config';
export default defineConfig({
  test: { exclude: [...configDefaults.exclude, 'tests/node/**'] },
  server: { strictPort: true, watch: { ignored: ['**/src/desktop/target/**'] } },
});
