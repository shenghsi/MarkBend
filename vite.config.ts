import { defineConfig } from 'vite';
export default defineConfig({
  server: { strictPort: true, watch: { ignored: ['**/src/desktop/target/**'] } },
});
