// @vitest-environment jsdom
import { expect, it, vi } from 'vitest';
vi.mock('@tauri-apps/api/core', () => ({ invoke: vi.fn(), isTauri: () => false }));
vi.mock('@tauri-apps/plugin-dialog', () => ({ ask: vi.fn(), open: vi.fn(), save: vi.fn() }));
it('keeps the edit surface when New is clicked during composition', async () => {
  document.body.innerHTML = '<div id="app"></div>';
  const { view } = await import('../../src/web/main');
  const source = 'composition text\n\n$x$\n\nEnd';
  view.dispatch({ changes: { from: 0, insert: source }, selection: { anchor: 0 } });
  expect(document.querySelector('.preview-math')).not.toBeNull();
  view.contentDOM.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true }));
  expect(view.compositionStarted).toBe(true);
  document.querySelector<HTMLButtonElement>('#new')!.click();
  await Promise.resolve();
  expect(view.state.doc.toString()).toBe(source);
  expect(document.querySelector('#status')!.textContent).toContain('Finish text input');
  expect(view.contentDOM.contentEditable).not.toBe('false');
  document.querySelector<HTMLButtonElement>('#source')!.click();
  expect(document.querySelector('#source')!.getAttribute('aria-pressed')).toBe('false');
  expect(document.querySelector('.preview-math')).not.toBeNull();
  expect(view.state.doc.toString()).toBe(source);
  view.destroy();
});
