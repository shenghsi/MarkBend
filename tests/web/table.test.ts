// @vitest-environment jsdom
import { afterEach, expect, it, vi } from 'vitest';
import { Compartment, EditorState, StateEffect } from '@codemirror/state';
import { EditorView } from '@codemirror/view';
import { history, redo, undo, undoDepth } from '@codemirror/commands';
import { markdown, markdownLanguage } from '@codemirror/lang-markdown';
import { livePreview } from '../../src/web/preview';
import { tableComposing, tableEditor, escapeCellPipes, tableCellField } from '../../src/web/table';
import { fromSource, normalize, savedSource, sourceExtensions, sourceField } from '../../src/web/source';

let outer: EditorView | undefined;
afterEach(() => { outer?.destroy(); outer = undefined; document.body.innerHTML = ''; vi.restoreAllMocks(); });
function setup(source: string) {
  const record = fromSource(source), display = new Compartment();
  outer = new EditorView({ parent: document.body, state: EditorState.create({
    doc: normalize(record.raw), selection: { anchor: normalize(record.raw).length },
    extensions: [sourceExtensions(record), history(), markdown({ base: markdownLanguage }), display.of(livePreview)],
  }) });
  const element = document.querySelector<HTMLElement>('.preview-table')!;
  return { editor: outer, display, element, table: tableEditor(element)!,
    source: () => savedSource(outer!.state.field(sourceField)) };
}
it('edits table cells with one source patch and one outer history, retaining all other bytes', () => {
  const original = '\uFEFFBefore\r\n\r\n|  Header  | Second |\r\n| :--- | ---: |\r\n| first | 😀 last |\r\n\r\nAfter\n';
  const { editor, table, element, source } = setup(original);
  element.querySelector('td')!.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true }));
  const child = table.child!; expect(child).toBeDefined();
  child.dispatch({ changes: { from: 0, to: child.state.doc.length, insert: '日本語 | x' } });
  expect(source()).toBe(original.replace('first', '日本語 \\| x'));
  expect(document.querySelector('.preview-table')).toBe(element);
  expect(table.child).toBe(child); expect(child.state.doc.toString()).toBe('日本語 \\| x');
  expect(undoDepth(editor.state)).toBe(1); expect(undoDepth(child.state)).toBe(0);
  expect(undo(editor)).toBe(true); expect(source()).toBe(original); expect(child.state.doc.toString()).toBe('first');
  expect(redo(editor)).toBe(true); expect(source()).toBe(original.replace('first', '日本語 \\| x'));
  expect(child.state.doc.toString()).toBe('日本語 \\| x');
  table.finish(); expect(element.querySelector('td')!.textContent).toBe('日本語 | x');
});
it('edits empty, first, and last cells without changing cell-edge spaces or alignment rows', () => {
  const original = 'Intro\n\n| A | B |\n|:---|---:|\n|   | x\\|y  |\n\nEnd';
  const { table, source, editor } = setup(original);
  table.begin(1, 0); expect(table.child!.state.doc.length).toBe(0);
  table.child!.dispatch({ changes: { from: 0, insert: 'empty' } });
  expect(source()).toBe(original.replace('|   |', '|   empty|'));
  table.begin(0, 0); table.child!.dispatch({ changes: { from: 0, to: 1, insert: 'H' } });
  table.begin(1, 1); expect(table.child!.state.doc.toString()).toBe('x\\|y');
  table.child!.dispatch({ changes: { from: 4, insert: '😀' } });
  expect(source()).toBe(original.replace('|   |', '|   empty|').replace('| A |', '| H |').replace('x\\|y', 'x\\|y😀'));
  for (let i = 0; i < 3; i++) expect(undo(editor)).toBe(true);
  expect(source()).toBe(original);
});
it('keeps escaped pipes and handles backslash parity without accepting multiline input', () => {
  expect(escapeCellPipes('a|b\\|c\\\\|d')).toBe('a\\|b\\|c\\\\\\|d');
  const { table, source } = setup('| A | B |\n|---|---|\n| x | y |\n\nEnd');
  table.begin(1, 0);
  const child = table.child!;
  child.dispatch({ changes: { from: 1, insert: '\\' } });
  child.dispatch({ changes: { from: 2, insert: '|' }, selection: { anchor: 3 } });
  expect(child.state.doc.toString()).toBe('x\\|'); expect(child.state.selection.main.head).toBe(3);
  const captured = source(); child.dispatch({ changes: { from: 3, insert: '\nsecond' } });
  expect(source()).toBe(captured); expect(child.state.doc.toString()).toBe('x\\|');
});
it('destroys the cell edit surface when the table structure is removed or Source mode replaces it', () => {
  const original = 'Before\n\n| A | B |\n|---|---|\n| x | y |\n\nEnd';
  const { table, editor, display } = setup(original);
  table.begin(1, 0); const child = table.child!; const destroy = vi.spyOn(child, 'destroy');
  editor.dispatch({ changes: { from: original.indexOf('| A'), to: original.indexOf('\n\nEnd'), insert: 'Paragraph' } });
  expect(destroy).toHaveBeenCalledOnce(); expect(document.querySelector('.preview-table')).toBeNull();
  expect(editor.state.field(tableCellField)).toBeNull();
  undo(editor);
  const restored = tableEditor(document.querySelector('.preview-table')!)!;
  restored.begin(0, 1); const next = vi.spyOn(restored.child!, 'destroy');
  editor.dispatch({ effects: display.reconfigure([]) });
  expect(next).toHaveBeenCalledOnce(); expect(tableComposing(editor)).toBe(false);
});
it('keeps typed spaces inside the active cell range and protects tight delimiters from a final backslash', () => {
  const { table, source, editor } = setup('|A|B|\n|---|---|\n|x|y|\n\nEnd');
  table.begin(1, 0); const child = table.child!;
  child.dispatch({ changes: { from: 1, insert: '\\' }, selection: { anchor: 2 } });
  expect(child.state.doc.toString()).toBe('x\\\\');
  expect(source()).toContain('|x\\\\|y|');
  expect(table.child).toBe(child);
  undo(editor); expect(child.state.doc.toString()).toBe('x');
  child.dispatch({ changes: { from: 1, insert: ' ' }, selection: { anchor: 2 } });
  expect(child.state.doc.toString()).toBe('x ');
  child.dispatch({ changes: { from: 2, insert: 'word' }, selection: { anchor: 6 } });
  expect(child.state.doc.toString()).toBe('x word'); expect(source()).toContain('|x word|y|');
  child.dispatch({ changes: { from: 0, insert: ' ' } });
  expect(child.state.doc.toString()).toBe(' x word'); expect(source()).toContain('| x word|y|');
});
it('moves between cells with Tab and forwards keyboard Undo to the outer history', () => {
  const { table, source, editor, element } = setup('| A | B |\n|---|---|\n| x | y |\n\nEnd');
  const original = source(); table.begin(1, 0); const child = table.child!;
  child.dispatch({ changes: { from: 1, insert: 'new' } });
  child.contentDOM.dispatchEvent(new KeyboardEvent('keydown', { key: 'z', ctrlKey: true, bubbles: true, cancelable: true }));
  expect(source()).toBe(original); expect(undoDepth(editor.state)).toBe(0);
  child.contentDOM.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true }));
  expect(table.child).not.toBe(child); expect(table.child!.state.doc.toString()).toBe('y');
  editor.dispatch({ selection: { anchor: editor.state.doc.toString().indexOf('| A') } });
  table.child!.contentDOM.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true }));
  expect(table.child).toBeUndefined(); expect(element.querySelector('.editing-cell')).toBeNull();
  expect(document.querySelector('.preview-table')).toBe(element);
});
it('ends a cell with Enter without sending the handled key to table source reveal', () => {
  const { table, editor, element, source } = setup('| A | B |\n|---|---|\n| x | y |\n\nEnd');
  const original = source(); table.begin(1, 0);
  table.child!.contentDOM.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
  expect(table.child).toBeUndefined(); expect(document.querySelector('.preview-table')).toBe(element);
  expect(source()).toBe(original); expect(editor.state.selection.main.head).toBeGreaterThan(original.indexOf('\n\nEnd'));
  element.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
  expect(document.querySelector('.preview-table')).toBeNull(); expect(source()).toBe(original);
});
it('maps an active cell through edits before the table and updates source reveal positions', () => {
  const { table, editor, element, source } = setup('Before\n\n| A | B |\n|---|---|\n| x | y |\n\nEnd');
  table.begin(1, 1); const child = table.child!;
  editor.dispatch({ changes: { from: 0, insert: 'Prefix ' } });
  child.dispatch({ changes: { from: 1, insert: 'z' } });
  expect(source()).toBe('Prefix Before\n\n| A | B |\n|---|---|\n| x | yz |\n\nEnd');
  element.querySelector('.table-source')!.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true }));
  expect(editor.state.selection.main.head).toBe(source().indexOf('| A'));
});
it('defers table navigation and source reveal during composition and blocks read-only edits', () => {
  const { table, editor, element, source } = setup('| A | B |\n|---|---|\n| x | y |\n\nEnd');
  const original = source(); table.begin(1, 0); const child = table.child!;
  child.contentDOM.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true }));
  expect(tableComposing(editor)).toBe(true);
  child.contentDOM.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true }));
  element.querySelector('.table-source')!.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true }));
  expect(table.child).toBe(child); expect(source()).toBe(original);
  child.contentDOM.dispatchEvent(new CompositionEvent('compositionend', { bubbles: true }));
  editor.dispatch({ effects: StateEffect.appendConfig.of(EditorState.readOnly.of(true)) });
  child.dispatch({ changes: { from: 0, insert: 'blocked' } });
  expect(source()).toBe(original); expect(child.state.doc.toString()).toBe('x');
});
