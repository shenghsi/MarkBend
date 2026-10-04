// @vitest-environment jsdom
import { afterEach, expect, it, vi } from 'vitest';
import { Compartment, EditorState } from '@codemirror/state';
import { EditorView } from '@codemirror/view';
import { history, undo, redo, undoDepth } from '@codemirror/commands';
import { imageDrops } from '../../src/web/image-drop';
import { imageBasePath, imageDocument, imagePath, setImagePath } from '../../src/web/images';
import { imagePaste } from '../../src/web/image-paste';
import { linkVersion } from '../../src/web/links';
import { documentLanguage } from '../../src/web/document-language';
import { fromSource, normalize, savedSource, sourceExtensions, sourceField } from '../../src/web/source';
import { clipboardRequest } from '../../src/web/clipboard';

Object.defineProperty(Range.prototype, 'getClientRects', { configurable: true, value: () => [] });
Object.defineProperty(Range.prototype, 'getBoundingClientRect', { configurable: true, value: () => new DOMRect() });
const png = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]).buffer;
let view: EditorView | undefined;
afterEach(() => { view?.destroy(); view = undefined; document.body.replaceChildren(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });
function setup(source = '\uFEFF图😀\r\nTail\rEnd\n', at = 3) {
  let busy = false;
  const lock = new Compartment(), messages: string[] = [];
  const state = (text: string, id = 7) => EditorState.create({ doc: normalize(fromSource(text).raw),
    extensions: [sourceExtensions(fromSource(text)), documentLanguage(), history(), linkVersion,
      imagePath, imageBasePath.of('/notes/doc.md'), imageDocument.of(id), lock.of([]), imagePaste(() => {})] });
  const editor = view = new EditorView({ state: state(source), parent: document.body });
  vi.stubGlobal('devicePixelRatio', 2);
  const rect = vi.spyOn(editor.contentDOM, 'getBoundingClientRect').mockReturnValue(new DOMRect(0, 0, 500, 300));
  const hit = vi.fn(() => editor.contentDOM);
  Object.defineProperty(document, 'elementFromPoint', { configurable: true, value: hit });
  const coords = vi.spyOn(editor, 'posAtCoords').mockReturnValue(at);
  const read = vi.fn(async () => png), scale = vi.fn(async () => 2);
  const drops = imageDrops(editor, { read, scale, report: message => messages.push(message), blocked: () => busy ? 'Busy' : null });
  return { editor, drops, read, scale, messages, coords, rect, hit, lock, state, busy: (value: boolean) => { busy = value; },
    source: () => savedSource(editor.state.field(sourceField)), drop: (path = '/images/图 [a] %23#?.png') => drops.drop(path, { x: 200, y: 100 }) };
}
function pending<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>(finish => { resolve = finish; });
  return { promise, resolve };
}

it('inserts at the physical drop point without replacing the current selection and preserves exact Undo/Redo', async () => {
  const f = setup();
  f.editor.dispatch({ selection: { anchor: 4, head: 8 } });
  const before = f.source();
  await f.drop();
  expect(f.coords).toHaveBeenCalledWith({ x: 100, y: 50 });
  expect(f.read).toHaveBeenCalledWith('/images/图%20%5Ba%5D%20%2523%23%3F.png', '/notes/doc.md', 7);
  const inserted = '\uFEFF图😀![](<\/images/图%20%5Ba%5D%20%2523%23%3F.png>)\r\nTail\rEnd\n';
  expect(f.source()).toBe(inserted); expect(f.messages.at(-1)).toBe('Image inserted.');
  expect(undoDepth(f.editor.state)).toBe(1);
  undo(f.editor); expect(f.source()).toBe(before); expect(f.editor.state.selection.main.from).toBe(4);
  redo(f.editor); expect(f.source()).toBe(inserted);
});

it('rejects outside content, child editors, widgets, unsupported scale and missing positions before reading', async () => {
  for (const target of ['outside', 'child', 'widget', 'scale', 'position', 'viewport']) {
    const f = setup(); const before = f.source();
    if (target === 'outside') f.hit.mockReturnValue(document.body);
    if (target === 'child' || target === 'widget') {
      const dom = document.createElement('div'); dom.className = target === 'child' ? 'cm-content' : 'preview-widget';
      f.editor.contentDOM.append(dom); f.hit.mockReturnValue(dom);
    }
    if (target === 'scale') f.scale.mockResolvedValue(1);
    if (target === 'position') f.coords.mockReturnValue(null);
    if (target === 'viewport') vi.stubGlobal('visualViewport', { scale: 2, offsetLeft: 0, offsetTop: 0 });
    await f.drop(); expect(f.source()).toBe(before); expect(f.read).not.toHaveBeenCalled();
    f.editor.destroy(); view = undefined; document.body.replaceChildren(); vi.restoreAllMocks(); vi.unstubAllGlobals();
  }
});

it('rejects code, links, math, existing images, metadata and tables before reading', async () => {
  for (const [source, at] of [['`code`', 3], ['[label](url)', 3], ['$x^2$', 2], ['![alt](a.png)', 3],
    ['---\nkey: value\n---\n\nEnd', 10], ['| A |\n| - |\n| cell |', 16], ['```\ncode\n```', 6]] as const) {
    const f = setup(source, at); await f.drop();
    expect(f.source()).toBe(source); expect(f.read).not.toHaveBeenCalled(); expect(undoDepth(f.editor.state)).toBe(0);
    f.editor.destroy(); view = undefined; document.body.replaceChildren(); vi.restoreAllMocks();
  }
});

it('cancels pending reads after source, selection, path, tab, scroll, layout, scale, clipboard or disposal changes', async () => {
  for (const action of ['undo', 'selection', 'path', 'tab', 'scroll', 'layout', 'scale', 'ratio', 'clipboard', 'dispose']) {
    const f = setup('Text\n\nEnd', 2), read = pending<ArrayBuffer>(); f.read.mockReturnValue(read.promise);
    const result = f.drop(); await vi.waitFor(() => expect(f.read).toHaveBeenCalledTimes(1));
    if (action === 'undo') { f.editor.dispatch({ changes: { from: 0, insert: 'x' } }); undo(f.editor); }
    if (action === 'selection') f.editor.dispatch({ selection: { anchor: 1 } });
    if (action === 'path') f.editor.dispatch({ effects: setImagePath.of('/notes/other.md') });
    if (action === 'tab') f.editor.setState(f.state('Other', 9));
    if (action === 'scroll') f.editor.scrollDOM.scrollTop = 20;
    if (action === 'layout') f.rect.mockReturnValue(new DOMRect(0, 0, 400, 300));
    if (action === 'scale') f.scale.mockResolvedValue(1);
    if (action === 'ratio') vi.stubGlobal('devicePixelRatio', 1);
    if (action === 'clipboard') clipboardRequest(f.editor);
    if (action === 'dispose') f.drops.dispose();
    read.resolve(png); await result;
    expect(f.source()).toBe(action === 'tab' ? 'Other' : 'Text\n\nEnd'); expect(undoDepth(f.editor.state)).toBe(0);
    f.editor.destroy(); view = undefined; document.body.replaceChildren(); vi.restoreAllMocks(); vi.unstubAllGlobals();
  }
});

it('guards input before and after reads, rejects invalid bytes, and retains the source on read failure', async () => {
  const f = setup('Text', 2);
  f.busy(true); await f.drop(); expect(f.read).not.toHaveBeenCalled(); f.busy(false);
  f.editor.dispatch({ effects: f.lock.reconfigure(EditorState.readOnly.of(true)) }); await f.drop(); expect(f.read).not.toHaveBeenCalled();
  f.editor.dispatch({ effects: f.lock.reconfigure([]) });
  f.editor.contentDOM.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true }));
  await f.drop(); expect(f.read).not.toHaveBeenCalled();
  f.editor.contentDOM.dispatchEvent(new CompositionEvent('compositionend', { bubbles: true }));
  for (const bytes of [new ArrayBuffer(0), new Uint8Array([1, 2, 3]).buffer, new ArrayBuffer(8 * 1024 * 1024 + 1)]) {
    f.read.mockResolvedValue(bytes); await f.drop(); expect(f.source()).toBe('Text');
  }
  f.read.mockRejectedValue(new Error('Read failed')); await f.drop(); expect(f.messages.at(-1)).toContain('Read failed');
  const read = pending<ArrayBuffer>(); f.read.mockReturnValue(read.promise); const result = f.drop();
  await vi.waitFor(() => expect(f.messages.at(-1)).toBe('Checking dropped image…'));
  f.busy(true); read.resolve(png); await result; expect(f.source()).toBe('Text'); expect(f.messages.at(-1)).toBe('Busy');
});

it('cancels before coordinate mapping when layout changes during the scale lookup', async () => {
  const f = setup(), scale = pending<number>(); f.scale.mockReturnValue(scale.promise);
  const result = f.drop(); f.editor.scrollDOM.scrollTop = 1; scale.resolve(2); await result;
  expect(f.coords).not.toHaveBeenCalled(); expect(f.read).not.toHaveBeenCalled();
});

it('checks the complete proposed source limit before reading a dropped image', async () => {
  const prefix = 'Text\n\n```\n', suffix = '\n```';
  const source = prefix + 'x'.repeat(8 * 1024 * 1024 - prefix.length - suffix.length) + suffix;
  const f = setup(source, 2); await f.drop();
  expect(f.read).not.toHaveBeenCalled(); expect(f.source()).toBe(source);
  expect(f.messages.at(-1)).toContain('8 MiB document limit'); expect(undoDepth(f.editor.state)).toBe(0);
});
