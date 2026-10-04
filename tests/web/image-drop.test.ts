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
import { forceParsing } from '@codemirror/language';
import { livePreview } from '../../src/web/preview';
import { tableEditor } from '../../src/web/table';

Object.defineProperty(Range.prototype, 'getClientRects', { configurable: true, value: () => [] });
Object.defineProperty(Range.prototype, 'getBoundingClientRect', { configurable: true, value: () => new DOMRect() });
const png = Uint8Array.from(atob('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aDLsAAAAASUVORK5CYII='), c => c.charCodeAt(0)).buffer;
import { rasterHeader } from './raster-fixtures';
let view: EditorView | undefined;
afterEach(() => { view?.destroy(); view = undefined; document.body.replaceChildren(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });
function setup(source = '\uFEFF图😀\r\nTail\rEnd\n', at = 3, preview = false) {
  let busy = false;
  const lock = new Compartment(), messages: string[] = [];
  const state = (text: string, id = 7) => EditorState.create({ doc: normalize(fromSource(text).raw), selection: { anchor: preview ? normalize(fromSource(text).raw).length : 0 },
    extensions: [sourceExtensions(fromSource(text)), documentLanguage(), history(), linkVersion,
      imagePath, imageBasePath.of('/notes/doc.md'), imageDocument.of(id), lock.of([]), imagePaste(() => {}), ...(preview ? [livePreview] : [])] });
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
it('rejects small files with oversized dimensions before outer, inactive-cell and active-cell edits', async () => {
  for (const route of ['outer','inactive','active']) {
    const original=route==='outer'?'\uFEFF图😀\r\nEnd':'| A |\n| - |\n| 图😀 text |\n\nEnd';
    const f=setup(original,3,route!=='outer');let input=f.editor;
    if (route!=='outer') {
      const table=tableEditor(document.querySelector('.preview-table')!)!;
      if (route==='active') {table.begin(1,0);input=table.child!;vi.spyOn(input,'posAtCoords').mockReturnValue(2);f.hit.mockReturnValue(input.contentDOM);}
      else f.hit.mockReturnValue(document.querySelector('td')!);
    }
    if (route!=='inactive') input.dispatch({selection:{anchor:0,head:3}});
    const selection=input.state.selection;
    f.read.mockResolvedValue(rasterHeader('png',16385,1).buffer as ArrayBuffer);await f.drop();
    expect(f.messages.at(-1)).toContain('16,384');expect(f.source()).toBe(original);expect(undoDepth(f.editor.state)).toBe(0);
    expect(input.state.selection.eq(selection)).toBe(true);
    f.editor.destroy();view=undefined;document.body.replaceChildren();vi.restoreAllMocks();vi.unstubAllGlobals();
  }
});
it('checks SVG bytes before one exact source edit and rejects malformed SVG without history', async () => {
  const f = setup(), original = f.source();
  f.read.mockResolvedValue(new TextEncoder().encode('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 10"><rect width="20" height="10"/></svg>').buffer);
  await f.drop('/images/图.svg'); expect(f.messages.at(-1)).toBe('Image inserted.');
  expect(f.source()).toContain('/images/图.svg'); expect(undoDepth(f.editor.state)).toBe(1);
  undo(f.editor); expect(f.source()).toBe(original);
  f.read.mockResolvedValue(new TextEncoder().encode('<svg>').buffer);
  await f.drop('/images/invalid.svg'); expect(f.messages.at(-1)).toContain('valid SVG XML');
  expect(f.source()).toBe(original); expect(undoDepth(f.editor.state)).toBe(0);
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

it('appends to rendered cells, separates formatted text and preserves exact source history', async () => {
  const original = '\uFEFF| A | B |\r\n| - | - |\r| **图😀** | tail |\n\nEnd';
  const f = setup(original, 0, true), cell = document.querySelector<HTMLElement>('td')!;
  f.hit.mockReturnValue(cell.querySelector('strong')!); await f.drop('/images/a|b%7C&c.png');
  const expected = original.replace('**图😀**', '**图😀** ![](</images/a%7Cb%257C&amp;c.png>)');
  expect(f.source()).toBe(expected); expect(f.read).toHaveBeenCalledWith('/images/a%7Cb%257C&c.png', '/notes/doc.md', 7);
  expect(undoDepth(f.editor.state)).toBe(1); expect(tableEditor(document.querySelector('.preview-table')!)!.child).toBeDefined();
  undo(f.editor); expect(f.source()).toBe(original); redo(f.editor); expect(f.source()).toBe(expected);
});

it('inserts at the active child drop position without deleting selected text', async () => {
  const original = '| A | B |\n| - | - |\n| 图😀 text | tail |\n\nEnd', f = setup(original, 0, true);
  const table = tableEditor(document.querySelector('.preview-table')!)!; table.begin(1, 0);
  const child = table.child!; child.dispatch({ selection: { anchor: 0, head: 3 } });
  vi.spyOn(child, 'posAtCoords').mockReturnValue(3); f.hit.mockReturnValue(child.contentDOM);
  await f.drop('/images/a.png');
  const expected = original.replace('图😀 text', '图😀![](</images/a.png>) text');
  expect(f.source()).toBe(expected); expect(f.coords).not.toHaveBeenCalled(); expect(undoDepth(f.editor.state)).toBe(1);
  expect(table.child!.state.doc.toString()).toBe('图😀![](</images/a.png>) text');
  undo(f.editor); expect(f.source()).toBe(original); redo(f.editor); expect(f.source()).toBe(expected);
});

it('fills omitted cells and retains trailing slashes and Windows path punctuation', async () => {
  for (const active of [false, true]) {
    const original = '| A | B | C |\n| - | - | - |\n| one |\n\nEnd', f = setup(original, 0, true);
    const table = tableEditor(document.querySelector('.preview-table')!)!, cell = document.querySelectorAll('td')[2] as HTMLElement;
    if (active) { table.begin(1, 2); vi.spyOn(table.child!, 'posAtCoords').mockReturnValue(0); }
    f.hit.mockReturnValue(active ? table.child!.contentDOM : cell);
    await f.drop('C:\\images\\图 a|b.png');
    const expected = original.replace('| one |', '| one | | ![](<C:\\\\images\\\\图%20a%7Cb.png>) |');
    expect(f.source()).toBe(expected); expect(undoDepth(f.editor.state)).toBe(1); undo(f.editor); expect(f.source()).toBe(original);
    redo(f.editor); expect(f.source()).toBe(expected);
    f.editor.destroy(); view = undefined; document.body.replaceChildren(); vi.restoreAllMocks();
  }
  const original = '| A |\n| - |\n| tail\\ |\n\nEnd', f = setup(original, 0, true);
  f.hit.mockReturnValue(document.querySelector('td')!); await f.drop('/images/a.png');
  expect(f.source()).toBe(original.replace('tail\\', 'tail\\ ![](</images/a.png>)')); undo(f.editor); expect(f.source()).toBe(original);
});

it('cancels pending table drops after cell selection, cell end, source replacement, mode and child scroll changes', async () => {
  for (const action of ['selection', 'end', 'source', 'mode', 'scroll', 'clipboard', 'composition']) {
    const original = '| A |\n| - |\n| text |\n\nEnd', f = setup(original, 0, true), read = pending<ArrayBuffer>();
    const table = tableEditor(document.querySelector('.preview-table')!)!; table.begin(1, 0);
    const child = table.child!; vi.spyOn(child, 'posAtCoords').mockReturnValue(2); f.hit.mockReturnValue(child.contentDOM);
    f.read.mockReturnValue(read.promise); const result = f.drop(); await vi.waitFor(() => expect(f.read).toHaveBeenCalledTimes(1));
    if (action === 'selection') child.dispatch({ selection: { anchor: 1 } });
    if (action === 'end') table.finish();
    if (action === 'source') f.editor.dispatch({ changes: { from: 0, to: f.editor.state.doc.length, insert: 'Other' } });
    if (action === 'mode') f.editor.setState(f.state('Other', 9));
    if (action === 'scroll') child.scrollDOM.scrollLeft = 10;
    if (action === 'clipboard') clipboardRequest(f.editor);
    if (action === 'composition') child.contentDOM.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true }));
    read.resolve(png); await result;
    expect(f.source()).toBe(['source', 'mode'].includes(action) ? 'Other' : original);
    f.editor.destroy(); view = undefined; document.body.replaceChildren(); vi.restoreAllMocks();
  }
});

it('rejects protected active cell source and table controls before reading', async () => {
  for (const text of ['`code`', '$x^2$', '[link](url)', '![image](a.png)', '<b>raw</b>']) {
    const original = `| A |\n| - |\n| ${text} |\n\nEnd`, f = setup(original, 0, true);
    const table = tableEditor(document.querySelector('.preview-table')!)!; table.begin(1, 0);
    vi.spyOn(table.child!, 'posAtCoords').mockReturnValue(text.startsWith('<') ? 1 : 3); f.hit.mockReturnValue(table.child!.contentDOM);
    await f.drop(); expect(f.source()).toBe(original); expect(f.read).not.toHaveBeenCalled();
    f.hit.mockReturnValue(document.querySelector('.table-source')!); await f.drop(); expect(f.read).not.toHaveBeenCalled();
    f.editor.destroy(); view = undefined; document.body.replaceChildren(); vi.restoreAllMocks();
  }
});

it('isolates active, inactive and omitted cell drops from adjacent typing', async () => {
  for (const route of ['active', 'inactive', 'omitted']) {
    const original = '| A | B |\n| - | - |\n| text |\n\nEnd', f = setup(original, 0, true);
    let table = tableEditor(document.querySelector('.preview-table')!)!; table.begin(1, 0);
    table.child!.dispatch({ changes: { from: 0, insert: 'before ' }, userEvent: 'input.type' });
    const before = f.source();
    if (route === 'active') { vi.spyOn(table.child!, 'posAtCoords').mockReturnValue(7); f.hit.mockReturnValue(table.child!.contentDOM); }
    else {
      if (route === 'inactive') table.finish();
      f.hit.mockReturnValue(document.querySelectorAll('td')[route === 'omitted' ? 1 : 0] as HTMLElement);
    }
    await f.drop('/images/a.png'); const dropped = f.source();
    expect(dropped).not.toBe(before); expect(undoDepth(f.editor.state)).toBe(2);
    table = tableEditor(document.querySelector('.preview-table')!)!;
    table.child!.dispatch({ changes: { from: table.child!.state.doc.length, insert: ' after' }, userEvent: 'input.type' });
    const after = f.source(); expect(undoDepth(f.editor.state)).toBe(3);
    undo(f.editor); expect(f.source()).toBe(dropped);
    undo(f.editor); expect(f.source()).toBe(before);
    undo(f.editor); expect(f.source()).toBe(original);
    redo(f.editor); expect(f.source()).toBe(before); redo(f.editor); expect(f.source()).toBe(dropped); redo(f.editor); expect(f.source()).toBe(after);
    f.editor.destroy(); view = undefined; document.body.replaceChildren(); vi.restoreAllMocks();
  }
});

it('captures cell selection and horizontal scroll before the native scale lookup', async () => {
  for (const action of ['selection', 'scroll']) {
    const original = '| A |\n| - |\n| text |\n\nEnd', f = setup(original, 0, true), scale = pending<number>();
    const table = tableEditor(document.querySelector('.preview-table')!)!; table.begin(1, 0);
    vi.spyOn(table.child!, 'posAtCoords').mockReturnValue(2); f.hit.mockReturnValue(table.child!.contentDOM);
    f.scale.mockReturnValue(scale.promise); const result = f.drop();
    if (action === 'selection') table.child!.dispatch({ selection: { anchor: 1 } }); else table.child!.scrollDOM.scrollLeft = 10;
    scale.resolve(2); await result; expect(f.read).not.toHaveBeenCalled(); expect(f.source()).toBe(original);
    f.editor.destroy(); view = undefined; document.body.replaceChildren(); vi.restoreAllMocks();
  }
});

it('checks omitted-cell padding against the complete source limit before reading', async () => {
  const prefix = '| A | B |\n| - | - |\n| text |\n\n```\n', suffix = '\n```\n\nEnd';
  const original = prefix + 'x'.repeat(8 * 1024 * 1024 - prefix.length - suffix.length) + suffix;
  const f = setup(original, 0, true);
  f.editor.dispatch({ selection: { anchor: prefix.indexOf('```') } });
  expect(forceParsing(f.editor, prefix.length, 10000)).toBe(true);
  await vi.waitFor(() => expect(document.querySelector('.preview-table')).not.toBeNull());
  f.hit.mockReturnValue(document.querySelectorAll('td')[1] as HTMLElement);
  await f.drop('/images/a.png'); expect(f.read).not.toHaveBeenCalled(); expect(f.source()).toBe(original);
  expect(f.messages.at(-1)).toContain('8 MiB document limit'); expect(undoDepth(f.editor.state)).toBe(0);
});
