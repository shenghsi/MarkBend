// @vitest-environment jsdom
import { expect, it, vi } from 'vitest';
const mocks = vi.hoisted(() => ({ invoke: vi.fn(), save: vi.fn(), ask: vi.fn() }));
vi.mock('@tauri-apps/api/core', () => ({ invoke: mocks.invoke, isTauri: () => true }));
vi.mock('@tauri-apps/plugin-dialog', () => ({ ask: mocks.ask, open: vi.fn(), save: mocks.save }));
vi.mock('@tauri-apps/api/window', () => ({ getCurrentWindow: () => ({ onCloseRequested: vi.fn() }) }));
it('retains the pending destination and captured baseline after another Save As attempt', async () => {
  document.body.innerHTML = '<div id="app"></div>';
  mocks.save.mockResolvedValueOnce('/tmp/first.md').mockResolvedValueOnce('/tmp/second.md');
  mocks.invoke.mockRejectedValueOnce({ message: 'read failed', uncertain: true }).mockResolvedValueOnce(undefined);
  const { view } = await import('../../src/web/main');
  view.dispatch({ changes: { from: 0, insert: 'captured' } });
  document.querySelector<HTMLButtonElement>('#save-as')!.click();
  await vi.waitFor(() => expect(document.querySelector('#status')!.textContent).toContain('uncertain'));
  view.dispatch({ changes: { from: 8, insert: ' newer' } });
  document.querySelector<HTMLButtonElement>('#save-as')!.click();
  await vi.waitFor(() => expect(document.querySelector('#status')!.textContent).toContain('Check the last save'));
  expect(mocks.save).toHaveBeenCalledTimes(1);
  expect(mocks.invoke).toHaveBeenCalledTimes(1);
  document.querySelector<HTMLButtonElement>('#check')!.click();
  await vi.waitFor(() => expect(document.querySelector('#status')!.textContent).toBe('first.md • Unsaved'));
  expect(view.state.doc.toString()).toBe('captured newer');
  view.destroy();
});
