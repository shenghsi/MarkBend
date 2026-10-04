// @vitest-environment jsdom
import { afterEach, expect, it, vi } from 'vitest';
import { Compartment, EditorState, StateEffect } from '@codemirror/state';
import { EditorView } from '@codemirror/view';
import { history, redo, undo, undoDepth } from '@codemirror/commands';
import { markdown, markdownLanguage } from '@codemirror/lang-markdown';
import { livePreview } from '../../src/web/preview';
import { tableComposing, tableEditor, escapeCellPipes, tableCellField } from '../../src/web/table';
import { fromSource, normalize, savedSource, sourceExtensions, sourceField } from '../../src/web/source';
import { tablePlan, TableCommand } from '../../src/web/table-commands';

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
it('runs every structure command as one history event with exact mixed-ending Undo/Redo', () => {
  const original = '\uFEFFBefore\r\n\r\n| A | B |\r\n| :--- | ---: |\r\n| x\\|y | 日本語😀 |\r\n| c | d |\r\n\r\nAfter\n';
  const { editor, source } = setup(original);
  const cases: [TableCommand, string][] = [
    ['row-above', original.replace('| x\\|y', '| | |\r\n| x\\|y')],
    ['row-below', original.replace('| c | d |', '| | |\r\n| c | d |')],
    ['delete-row', original.replace('| x\\|y | 日本語😀 |\r\n', '')],
    ['column-left', original.replace('| A | B |', '| A | Column | B |').replace('| :--- | ---: |', '| :--- | --- | ---: |').replace('| x\\|y | 日本語😀 |', '| x\\|y | | 日本語😀 |').replace('| c | d |', '| c | | d |')],
    ['column-right', original.replace('| A | B |', '| A | B | Column |').replace('| :--- | ---: |', '| :--- | ---: | --- |').replace('| x\\|y | 日本語😀 |', '| x\\|y | 日本語😀 | |').replace('| c | d |', '| c | d | |')],
    ['delete-column', original.replace('| A | B |', '| A |').replace('| :--- | ---: |', '| :--- |').replace('| x\\|y | 日本語😀 |', '| x\\|y |').replace('| c | d |', '| c |')],
    ['align-left', original.replace('---:', ':---')],
    ['align-center', original.replace('---:', ':---:')],
    ['align-right', original],
  ];
  for (const [command, expected] of cases) {
    const table = tableEditor(document.querySelector('.preview-table')!)!; table.begin(1, 1);
    expect(table.command(command), command).toBe(true); expect(source(), command).toBe(expected);
    if (expected !== original) {
      expect(undoDepth(editor.state), command).toBe(1);
      expect(undo(editor), command).toBe(true); expect(source(), command).toBe(original);
      expect(redo(editor), command).toBe(true); expect(source(), command).toBe(expected);
      expect(undo(editor), command).toBe(true); expect(source(), command).toBe(original);
    } else expect(undoDepth(editor.state)).toBe(0);
  }
});
it('supports zero body rows, no final ending, indentation, and tables without outer pipes', () => {
  const original = 'Before\r\n\r\n  A | B\r\n  --- | ---:';
  const { editor, source } = setup(original);
  editor.dispatch({ selection: { anchor: 0 } });
  let table = tableEditor(document.querySelector('.preview-table')!)!;
  expect(table.command('row-below')).toBe(true);
  expect(source()).toBe(original + '\r\n  | | |');
  table = tableEditor(document.querySelector('.preview-table')!)!;
  expect(table.child!.state.doc.toString()).toBe('');
  expect(table.command('delete-row')).toBe(true);
  expect(source()).toBe(original + '\r\n');
  undo(editor); undo(editor); expect(source()).toBe(original); editor.dispatch({ selection: { anchor: 0 } });
  table = tableEditor(document.querySelector('.preview-table')!)!; table.begin(0, 0);
  expect(table.command('column-left')).toBe(true);
  expect(source()).toBe('Before\r\n\r\n  Column |A | B\r\n  --- |--- | ---:');
  undo(editor); expect(source()).toBe(original);
});
it('preserves short rows, extra cells, and escaped pipes during column commands', () => {
  const original = '|A|B|C|\n|---|---|---|\n|x|\n|a\\|b|c|d|extra|\n\nEnd';
  const { editor, source } = setup(original);
  const table = tableEditor(document.querySelector('.preview-table')!)!; table.begin(0, 2);
  expect(table.command('column-right')).toBe(true);
  expect(source()).toBe('|A|B|C| Column |\n|---|---|---| --- |\n|x| | | |\n|a\\|b|c|d| |extra|\n\nEnd');
  expect(undo(editor)).toBe(true); expect(source()).toBe(original);
});
it('keeps a valid one-column table when deleting an edge column from rows without outer pipes', () => {
  const original = 'A | B\n--- | ---:\nx | y\n\nEnd';
  const { editor, source } = setup(original);
  const table = tableEditor(document.querySelector('.preview-table')!)!; table.begin(1, 1);
  expect(table.command('delete-column')).toBe(true);
  expect(source()).toBe('|A |\n|--- |\n|x |\n\nEnd');
  expect(document.querySelectorAll('.preview-table th')).toHaveLength(1);
  expect(undo(editor)).toBe(true); expect(source()).toBe(original);
});
it('returns keyboard focus to the outer edit surface when Undo removes the active column', () => {
  const { editor, source } = setup('|A|B|\n|---|---|\n|x|y|\n\nEnd');
  const original = source(); const table = tableEditor(document.querySelector('.preview-table')!)!;
  table.begin(1, 1); expect(table.command('column-right')).toBe(true);
  const child = tableEditor(document.querySelector('.preview-table')!)!.child!;
  child.contentDOM.dispatchEvent(new KeyboardEvent('keydown', { key: 'z', ctrlKey: true, bubbles: true, cancelable: true }));
  expect(source()).toBe(original); expect(document.activeElement).toBe(editor.contentDOM);
  expect(redo(editor)).toBe(true); expect(document.querySelectorAll('.preview-table th')).toHaveLength(3);
});
it('rejects guarded structure commands without destroying the active cell or changing source', () => {
  const original = '|A|\n|---|\n|x|\n\nEnd';
  const { table, source, element, editor } = setup(original); table.begin(0, 0); const child = table.child!;
  expect(table.command('delete-row')).toBe(false); expect(table.command('row-above')).toBe(false);
  expect(table.command('delete-column')).toBe(false); expect(table.child).toBe(child); expect(source()).toBe(original);
  child.contentDOM.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true }));
  expect(table.command('column-right')).toBe(false); expect(table.child).toBe(child);
  element.querySelector<HTMLButtonElement>('[data-command="row-below"]')!.click();
  expect(source()).toBe(original); expect(table.child).toBe(child);
  child.contentDOM.dispatchEvent(new CompositionEvent('compositionend', { bubbles: true }));
  editor.dispatch({ effects: StateEffect.appendConfig.of(EditorState.readOnly.of(true)) });
  expect(table.command('row-below')).toBe(false); expect(source()).toBe(original);
});
it('disables structure commands for nested tables with an explicit source hint', () => {
  const { table, element, source, editor } = setup('> |A|B|\n> |---|---|\n> |x|y|\n\nEnd');
  const captured = source(); table.begin(1, 0); const child = table.child!;
  expect(table.command('row-below')).toBe(false); expect(table.child).toBe(child); expect(source()).toBe(captured);
  expect(element.querySelector<HTMLButtonElement>('[data-command="row-below"]')!.disabled).toBe(true);
  expect(element.querySelector<HTMLButtonElement>('[data-command="row-below"]')!.title).toContain('lists or quotes');
  expect(() => tablePlan(editor.state, captured.indexOf('|A'), 'column-right', 1, 0)).toThrow('lists or quotes');
});
it('opens omitted cells without a source edit and materializes only needed slots in one Undo step', () => {
  const original = '\uFEFFBefore\r\n\r\n|A|B|C|D|\r\n|---|---|---|---|\r\n|x|\r\n\r\nEnd\n';
  const { table, editor, source } = setup(original); table.begin(1, 1);
  expect(table.child!.state.doc.length).toBe(0); expect(source()).toBe(original); expect(undoDepth(editor.state)).toBe(0);
  table.child!.contentDOM.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true }));
  expect(source()).toBe(original); expect(undoDepth(editor.state)).toBe(0);
  table.begin(1, 3); const child = table.child!;
  child.dispatch({ changes: { from: 0, insert: '日本語 | 😀' }, selection: { anchor: 8 } });
  const changed = original.replace('|x|\r\n', '|x| | | 日本語 \\| 😀 |\r\n');
  expect(source()).toBe(changed); expect(table.child).toBe(child); expect(undoDepth(editor.state)).toBe(1);
  expect(undo(editor)).toBe(true); expect(source()).toBe(original); expect(child.state.doc.length).toBe(0);
  expect(redo(editor)).toBe(true); expect(source()).toBe(changed); expect(child.state.doc.toString()).toBe('日本語 \\| 😀');
});
it('handles spaces-only edits, existing padding, backslashes, and rows without trailing pipes', () => {
  const original = '|A|B|C|\n|---|---|---|\nx  \n\nEnd';
  const { table, source, editor } = setup(original); table.begin(1, 1); const child = table.child!;
  child.dispatch({ changes: { from: 0, insert: ' ' } });
  expect(source()).toBe(original.replace('x  \n', 'x  |   |\n')); expect(child.state.doc.toString()).toBe(' ');
  expect(undo(editor)).toBe(true); expect(source()).toBe(original); expect(child.state.doc.toString()).toBe('');
  child.dispatch({ changes: { from: 0, insert: 'a\\|b\\' } });
  expect(source()).toBe(original.replace('x  \n', 'x  | a\\|b\\ |\n')); expect(child.state.doc.toString()).toBe('a\\|b\\');
  undo(editor); expect(source()).toBe(original);
});
it('keeps nested prefixes and rejects empty or multiline omitted-cell changes', () => {
  const original = '> |A|B|C|\n> |---|---|---|\n> |x|\n\nEnd';
  const { table, source, editor } = setup(original); table.begin(1, 1); const child = table.child!;
  child.dispatch({ changes: { from: 0, insert: '' } });
  child.dispatch({ changes: { from: 0, insert: 'first\nsecond' } });
  expect(source()).toBe(original); expect(child.state.doc.length).toBe(0); expect(undoDepth(editor.state)).toBe(0);
  child.dispatch({ changes: { from: 0, insert: '新' } });
  expect(source()).toBe(original.replace('> |x|\n', '> |x| 新 |\n'));
  undo(editor); expect(source()).toBe(original); expect(child.state.doc.length).toBe(0);
});
it('maps virtual cells through prefix edits and rejects input after their row is removed', () => {
  const { table, editor, source } = setup('Before\n\n|A|B|\n|---|---|\n|x|\n\nEnd');
  table.begin(1, 1); const child = table.child!;
  editor.dispatch({ changes: { from: 0, insert: 'Prefix ' } });
  child.dispatch({ changes: { from: 0, insert: 'added' } });
  expect(source()).toContain('Prefix Before'); expect(source()).toContain('|x| added |');
  const start = editor.state.doc.toString().indexOf('|x|');
  editor.dispatch({ changes: { from: start, to: editor.state.doc.length, insert: 'End' } });
  const captured = source(); child.dispatch({ changes: { from: 0, insert: 'stale' } });
  expect(source()).toBe(captured);
});
it('distinguishes a final escaped pipe from a delimiter and retains trailing padding', () => {
  const original = '|A|B|C|\n|---|---|---|\nx\\|  \n\nEnd';
  const { table, source, editor } = setup(original); table.begin(1, 1);
  table.child!.dispatch({ changes: { from: 0, insert: 'new' } });
  expect(source()).toBe(original.replace('x\\|  \n', 'x\\|  | new |\n'));
  undo(editor); expect(source()).toBe(original); expect(table.child!.state.doc.length).toBe(0);
  redo(editor); expect(table.child!.state.doc.toString()).toBe('new');
});
it('restores omitted-cell edits through mode changes and source edits before the table', () => {
  const original = 'Before\n\n|A|B|\n|---|---|\n|x|\n\nEnd';
  const { editor, table, source, display } = setup(original); table.begin(1, 1);
  table.child!.dispatch({ changes: { from: 0, insert: ' value ' } });
  const changed = original.replace('|x|\n', '|x|  value  |\n'); expect(source()).toBe(changed);
  editor.dispatch({ effects: display.reconfigure([]) });
  editor.dispatch({ changes: { from: 0, insert: 'Prefix ' } });
  undo(editor); expect(source()).toBe(changed);
  undo(editor); expect(source()).toBe(original);
  redo(editor); expect(source()).toBe(changed);
  editor.dispatch({ effects: display.reconfigure(livePreview) });
  const restored = tableEditor(document.querySelector('.preview-table')!)!;
  restored.begin(1, 1); expect(restored.child!.state.doc.toString()).toBe('value');
  undo(editor); expect(source()).toBe(original); expect(restored.child!.state.doc.length).toBe(0);
  redo(editor); expect(source()).toBe(changed);
});
