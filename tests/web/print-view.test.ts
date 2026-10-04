// @vitest-environment jsdom
import { afterEach, expect, it, vi } from 'vitest';
import { EditorState } from '@codemirror/state';
import { history, undoDepth } from '@codemirror/commands';
import { invoke } from '@tauri-apps/api/core';
import { documentLanguage } from '../../src/web/document-language';
import { fromSource, normalize, savedSource, sourceExtensions, sourceField } from '../../src/web/source';
import { printView, showPrintView, PrintSnapshot } from '../../src/web/print-view';
vi.mock('@tauri-apps/api/core', () => ({ invoke: vi.fn(), isTauri: () => true }));
Object.defineProperty(HTMLDialogElement.prototype, 'showModal', { configurable: true, writable: true, value() { this.setAttribute('open', ''); } });
const projections: ReturnType<typeof printView>[] = [];
afterEach(() => { for (const projection of projections.splice(0)) projection.dispose(); window.dispatchEvent(new Event('pagehide')); document.body.replaceChildren(); vi.restoreAllMocks(); vi.unstubAllGlobals(); vi.mocked(invoke).mockReset(); vi.useRealTimers(); });
function snapshot(source: string): PrintSnapshot {
  const record = fromSource(source);
  return { state: EditorState.create({ doc: normalize(record.raw), extensions: [sourceExtensions(record), history(), documentLanguage()] }),
    id: 42, path: '/tmp/writing.md', title: 'Writing.md' };
}
function create(source: PrintSnapshot, renderers?: Parameters<typeof printView>[1]) {
  const projection = printView(source, renderers); projections.push(projection); document.body.append(projection.element); return projection;
}
it('renders a complete immutable document, GFM, metadata and highlighted code without source or history edits', async () => {
  const original = '\uFEFF---\r\ntitle: 文😀\r\n---\r\n# First\n\n- [x] Done\n- [ ] Next\n\n| A | B |\n| - | - |\n| 一 | 二 |\n\n~~removed~~ **strong**\n\n```js\nconst x = "word";\n```\n\n'
    + Array.from({ length: 1000 }, (_, i) => `Paragraph ${i}\n\n`).join('') + '# Final sentinel\n';
  const captured = snapshot(original), previous = captured.state;
  const projection = create(captured); captured.title = 'Later'; captured.id = 100; captured.path = '/tmp/other.md';
  expect(await projection.ready).toEqual([]);
  expect(projection.element.querySelector('.print-metadata')!.textContent).toContain('title: 文😀');
  expect(projection.element.querySelector('table')!.textContent).toContain('一');
  expect(projection.element.querySelectorAll('input[type=checkbox]')).toHaveLength(2);
  expect(projection.element.querySelector('del')!.textContent).toBe('removed');
  expect(projection.element.querySelector('code .tok-keyword')!.textContent).toBe('const');
  expect(projection.element.querySelectorAll('p')).toHaveLength(1001);
  expect(projection.element.querySelectorAll('h1')[1].textContent).toBe('Final sentinel');
  expect(projection.snapshot).toMatchObject({ id: 42, path: '/tmp/writing.md', title: 'Writing.md' });
  expect(projection.snapshot.state).toBe(previous); expect(savedSource(previous.field(sourceField))).toBe(original); expect(undoDepth(previous)).toBe(0);
});
it('renders bundled math in body and footnotes and preserves note resource restrictions', async () => {
  const projection = create(snapshot('Formula $x^2$. Note[^one].\n\n$$\n\\frac{1}{2}\n$$\n\n```math\nx^3\n```\n\n```latex\nx^4\n```\n\n[^one]: Math $y^2$, ![ALT](local.png), <b>literal</b>, [link](https://example.com), [^nested].\n'));
  expect(await projection.ready).toEqual([]);
  expect(projection.element.querySelectorAll('mjx-container')).toHaveLength(5);
  expect(projection.element.querySelectorAll('svg path').length).toBeGreaterThan(0);
  expect(projection.element.textContent).toContain('ALT'); expect(projection.element.textContent).toContain('<b>');
  expect(projection.element.textContent).toContain('[^nested]');
  expect(projection.element.querySelector('iframe, img, [href], [src], form, button')).toBeNull();
  expect(vi.mocked(invoke)).not.toHaveBeenCalled();
});
it('isolates authored HTML and strips actions from generated links and renderer output', async () => {
  const projection = create(snapshot('[Go](https://example.com)\n\n<div><script>bad()</script><img src="https://example.com/pixel"><form action="https://example.com">Text</form></div>\n\n$z$\n'), {
    formula: async () => '<svg><a href="https://example.com"><text>safe</text></a><foreignObject><button>bad</button></foreignObject></svg>', diagram: async () => '',
  });
  const frame = projection.element.querySelector('iframe')!;
  expect(frame.getAttribute('sandbox')).toBe(''); expect(frame.srcdoc).toContain("default-src 'none'"); expect(frame.srcdoc).not.toContain('<script>');
  frame.dispatchEvent(new Event('load')); const warnings = await projection.ready;
  expect(warnings).toHaveLength(1); expect(warnings[0]).toContain('clipped');
  expect(projection.element.querySelector('[href], script, form, foreignObject, button, img')).toBeNull();
});
it('keeps inline HTML literal without splitting a paragraph into large empty frames', async () => {
  const projection = create(snapshot('Before <kbd>Enter</kbd> after.'));
  expect(await projection.ready).toEqual(['Inline HTML is printed as source.']);
  expect(projection.element.querySelector('p')!.textContent).toBe('Before <kbd>Enter</kbd> after.');
  expect(projection.element.querySelector('iframe')).toBeNull();
});
it('settles failures with visible source and ignores late formula results after disposal', async () => {
  let resolve!: (html: string) => void;
  const projection = create(snapshot('$pending$\n\n```mermaid\nbad diagram\n```'), {
    formula: () => new Promise(done => { resolve = done; }), diagram: async () => { throw new Error('bad diagram'); },
  });
  await vi.waitFor(() => expect(projection.element.querySelector('.print-error')!.textContent).toContain('bad diagram'));
  projection.dispose(); await projection.ready; resolve('<svg><text>late</text></svg>'); await Promise.resolve();
  expect(projection.element.querySelector('svg')).toBeNull(); expect(projection.element.isConnected).toBe(false);
});
it('captures the local image document and path and releases its Blob URL on close', async () => {
  const bytes = Uint8Array.from([137,80,78,71,13,10,26,10]).buffer;
  vi.mocked(invoke).mockResolvedValue(bytes);
  const createURL = vi.fn(() => 'blob:print-image'), revoke = vi.fn();
  vi.stubGlobal('URL', class extends URL { static createObjectURL = createURL; static revokeObjectURL = revoke; });
  const captured = snapshot('![Local](picture.png)\n\n![Reference][picture]\n\n[picture]: second.png');
  const projection = create(captured); captured.id = 99; captured.path = '/tmp/later.md';
  await vi.waitFor(() => expect(projection.element.querySelectorAll('img')).toHaveLength(2));
  const calls = vi.mocked(invoke).mock.calls;
  expect(calls[0]).toEqual(['read_image', { document: 42, documentPath: '/tmp/writing.md', destination: 'picture.png' }]);
  expect(calls[1]).toEqual(['read_image', { document: 42, documentPath: '/tmp/writing.md', destination: 'second.png' }]);
  projection.element.querySelectorAll('img').forEach(image => image.dispatchEvent(new Event('load')));
  expect(await projection.ready).toEqual([]); projection.dispose(); expect(revoke).toHaveBeenCalledTimes(2);
});
it('times out slow jobs and cancels image publication without falling back to another tab', async () => {
  vi.useFakeTimers(); let resolve!: (bytes: ArrayBuffer) => void;
  vi.mocked(invoke).mockImplementation(() => new Promise(done => { resolve = done; }));
  const projection = create(snapshot('![Missing](missing.png) $slow$'), { formula: () => new Promise(() => {}), diagram: async () => '' });
  await vi.advanceTimersByTimeAsync(15000);
  expect(await projection.ready).toHaveLength(2);
  resolve(Uint8Array.from([137,80,78,71,13,10,26,10]).buffer); await Promise.resolve(); await Promise.resolve();
  expect(projection.element.querySelector('img, svg')).toBeNull(); expect(projection.element.textContent).toContain('slow');
  expect(vi.mocked(invoke)).toHaveBeenCalledTimes(1);
});
it('loads diagrams as isolated SVG images and releases URLs on load error, timeout, and close', async () => {
  const createURL = vi.fn((_blob: Blob) => 'blob:diagram'), revoke = vi.fn();
  vi.stubGlobal('URL', class extends URL { static createObjectURL = createURL; static revokeObjectURL = revoke; });
  const renderers = { formula: async () => '', diagram: async () => '<svg xmlns="http://www.w3.org/2000/svg"><style>rect{fill:white}</style><rect width="20" height="20"/></svg>' };
  const loaded = create(snapshot('```mermaid\nflowchart LR\nA-->B\n```'), renderers);
  await vi.waitFor(() => expect(loaded.element.querySelector('img')).not.toBeNull());
  expect(loaded.element.querySelector('style, svg')).toBeNull();
  expect(createURL.mock.calls[0][0]).toMatchObject({ type: 'image/svg+xml' });
  loaded.element.querySelector('img')!.dispatchEvent(new Event('load'));
  expect(await loaded.ready).toEqual([]); loaded.dispose(); expect(revoke).toHaveBeenCalledTimes(1);
  const failed = create(snapshot('```mermaid\ninvalid\n```'), renderers);
  await vi.waitFor(() => expect(failed.element.querySelector('img')).not.toBeNull());
  failed.element.querySelector('img')!.dispatchEvent(new Event('error'));
  expect(await failed.ready).toHaveLength(1); expect(failed.element.textContent).toContain('invalid'); expect(revoke).toHaveBeenCalledTimes(2);
  vi.useFakeTimers(); const slow = create(snapshot('```mermaid\nslow\n```'), renderers);
  await vi.advanceTimersByTimeAsync(15000);
  expect(await slow.ready).toHaveLength(1); expect(revoke).toHaveBeenCalledTimes(3); expect(slow.element.querySelector('img')).toBeNull();
});
it('enables Print only after the snapshot is ready and cleans up the modal', async () => {
  const show = vi.spyOn(HTMLDialogElement.prototype, 'showModal').mockImplementation(function (this: HTMLDialogElement) { this.setAttribute('open', ''); });
  const print = vi.spyOn(window, 'print').mockImplementation(() => {});
  const pending = showPrintView(snapshot('$x^2$'));
  const button = document.querySelector<HTMLButtonElement>('.print-controls button')!; expect(button.disabled).toBe(true);
  await pending; expect(button.disabled).toBe(false); button.click(); expect(print).toHaveBeenCalledTimes(1);
  document.querySelector<HTMLButtonElement>('.print-controls button:last-child')!.click();
  expect(document.querySelector('.print-dialog')).toBeNull(); expect(show).toHaveBeenCalledTimes(1);
});
