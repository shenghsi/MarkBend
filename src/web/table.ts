import { EditorSelection, EditorState, Facet, StateEffect, StateField, Transaction } from '@codemirror/state';
import { EditorView, keymap } from '@codemirror/view';
import { defaultKeymap, invertedEffects, redo, undo } from '@codemirror/commands';
import { syntaxTree } from '@codemirror/language';
import { SyntaxNode } from '@lezer/common';
import { renderedTable } from './renderers';
import { Cell, tableCells, editableTableCells } from './table-ranges';
import { findTable, tablePlan, TableCommand } from './table-commands';
export { tableCells } from './table-ranges';

interface ActiveCell { from: number; to: number; row: number; column: number; cellFrom: number; cellTo: number }
export const tableCellEffect = StateEffect.define<ActiveCell | null>({ map: (active, changes) => active ? { ...active,
  from: changes.mapPos(active.from, -1), to: changes.mapPos(active.to, 1),
  cellFrom: changes.mapPos(active.cellFrom, -1), cellTo: changes.mapPos(active.cellTo, 1) } : null });
export const tableSaveCommand = Facet.define<() => void, (() => void) | undefined>({ combine: values => values[0] });
export const tableFindCommand = Facet.define<() => void, (() => void) | undefined>({ combine: values => values[0] });
export const tableCellField: StateField<ActiveCell | null> = StateField.define<ActiveCell | null>({
  create: () => null,
  update(active, transaction) {
    if (active && transaction.docChanged && !transaction.isUserEvent('input.table')) {
      const oldTable = findTable(transaction.startState, active.from), nodes: SyntaxNode[] = [];
      for (let node = oldTable?.firstChild; node; node = node.nextSibling)
        if (node.name === 'TableHeader' || node.name === 'TableRow') nodes.push(node);
      const row = nodes[active.row];
      transaction.changes.iterChangedRanges((from, to) => {
        if (row && to > from && from <= row.from && to >= row.to) active = null;
      });
    }
    if (active && transaction.docChanged) active = { ...active,
      from: transaction.changes.mapPos(active.from, -1), to: transaction.changes.mapPos(active.to, 1),
      cellFrom: transaction.changes.mapPos(active.cellFrom, -1), cellTo: transaction.changes.mapPos(active.cellTo, 1) };
    for (const effect of transaction.effects) if (effect.is(tableCellEffect)) active = effect.value;
    if (active && transaction.docChanged) {
      const node = syntaxTree(transaction.state).resolveInner(active.from, 1);
      let table: SyntaxNode | null = node;
      while (table && table.name !== 'Table') table = table.parent;
      if (!table || table.from !== active.from || table.to !== active.to) return null;
      const cell = editableTableCells(table, (from, to) => transaction.state.doc.sliceString(from, to))[active.row]?.[active.column];
      if (cell?.virtual) return { ...active, cellFrom: cell.from, cellTo: cell.to };
      if (!cell || active.cellFrom < cell.slotFrom! || active.cellTo > cell.slotTo!) return null;
    }
    return active;
  },
  provide: () => invertedEffects.of(transaction => {
    const active = transaction.startState.field(tableCellField, false);
    return transaction.docChanged && active !== undefined ? [tableCellEffect.of(active)] : [];
  }),
});

export function escapeCellPipes(text: string): string {
  let result = '', slashes = 0;
  for (const character of text) {
    if (character === '|' && slashes % 2 === 0) result += '\\';
    result += character;
    slashes = character === '\\' ? slashes + 1 : 0;
  }
  return result;
}

const controllers = new WeakMap<HTMLElement, TableEditor>();
const activeEditors = new WeakMap<EditorView, TableEditor>();
export const tableComposing = (view: EditorView) => activeEditors.get(view)?.child?.compositionStarted || false;
export const tableEditor = (dom: HTMLElement) => controllers.get(dom);
export function endTableEdit(view: EditorView): boolean {
  if (view.compositionStarted || tableComposing(view)) return false;
  activeEditors.get(view)?.finish();
  if (view.state.field(tableCellField, false)) view.dispatch({ effects: tableCellEffect.of(null) });
  return true;
}

export class TableEditor {
  child?: EditorView;
  private row = 0;
  private column = 0;
  private syncing = false;
  private cells: Cell[][] = [];
  private source = '';
  private from = 0;
  private to = 0;
  private tools?: HTMLElement;
  constructor(readonly dom: HTMLElement, readonly outer: EditorView,
    from: number, to: number, source: string) {
    this.refresh(from, to, source);
    const caption = document.createElement('button'); caption.className = 'preview-caption table-source';
    caption.textContent = 'Table source'; caption.type = 'button';
    caption.addEventListener('mousedown', event => {
      event.preventDefault(); event.stopPropagation();
      if (tableComposing(outer) || outer.compositionStarted) return;
      this.finish(); outer.dispatch({ selection: { anchor: this.from }, scrollIntoView: true }); outer.focus();
    });
    dom.append(caption);
    this.tools = document.createElement('div'); this.tools.className = 'table-tools';
    const commands: [TableCommand, string][] = [
      ['row-above', 'Row above'], ['row-below', 'Row below'], ['delete-row', 'Delete row'],
      ['column-left', 'Column left'], ['column-right', 'Column right'], ['delete-column', 'Delete column'],
      ['align-left', 'Align left'], ['align-center', 'Align center'], ['align-right', 'Align right'],
    ];
    for (const [command, label] of commands) {
      const button = document.createElement('button'); button.type = 'button'; button.textContent = label;
      button.dataset.command = command;
      button.addEventListener('mousedown', event => { event.preventDefault(); event.stopPropagation(); });
      button.addEventListener('click', event => { event.preventDefault(); event.stopPropagation(); this.command(command); });
      this.tools.append(button);
    }
    dom.append(this.tools); this.updateTools();
    dom.addEventListener('mousedown', event => {
      const cell = (event.target as HTMLElement).closest('th, td');
      if (!cell) return;
      event.stopPropagation();
      if (this.child && this.child.dom.contains(event.target as Node)) return;
      event.preventDefault();
      const row = Number((cell as HTMLElement).dataset.row), column = Number((cell as HTMLElement).dataset.column);
      this.begin(row, column);
    });
    dom.addEventListener('keydown', event => {
      event.stopPropagation();
      if (event.target instanceof HTMLElement && event.target.matches('th, td') && event.key === 'Enter') {
        event.preventDefault(); this.begin(Number(event.target.dataset.row), Number(event.target.dataset.column));
      }
    });
    controllers.set(dom, this);
  }
  refresh(from: number, to: number, source: string): boolean {
    this.from = from; this.to = to; this.source = source;
    const node = syntaxTree(this.outer.state).resolveInner(from, 1);
    let table: SyntaxNode | null = node;
    while (table && table.name !== 'Table') table = table.parent;
    if (!table) return false;
    this.cells = editableTableCells(table, (a, b) => this.outer.state.doc.sliceString(a, b));
    const active = this.outer.state.field(tableCellField, false);
    if (this.child && !active) return false;
    if (this.child && active && this.cells[active.row]?.[active.column]) {
      this.cells[active.row][active.column] = { ...this.cells[active.row][active.column],
        from: active.cellFrom, to: active.cellTo };
    }
    // The widget starts at the table node, inside any container prefix. Render
    // row nodes without those prefixes; source patches still use exact ranges.
    const renderRows: string[] = [];
    for (let row = table.firstChild; row; row = row.nextSibling)
      if (row.name === 'TableHeader' || row.name === 'TableDelimiter' || row.name === 'TableRow')
        renderRows.push(this.outer.state.doc.sliceString(row.from, row.to));
    const fresh = document.createElement('div'); fresh.innerHTML = renderedTable(renderRows.join('\n'));
    const old = this.dom.querySelector('table'), next = fresh.querySelector('table');
    if (!next) return false;
    const oldRows = old?.querySelectorAll('tr'), newRows = next.querySelectorAll('tr');
    if (this.child && (!oldRows || oldRows.length !== newRows.length ||
      Array.from(newRows).some((row, index) => row.children.length !== oldRows[index].children.length) ||
      !this.cells[this.row]?.[this.column])) return false;
    if (this.child && old) {
      newRows.forEach((row, r) => Array.from(row.children).forEach((cell, c) => {
        if (r !== this.row || c !== this.column) oldRows![r].children[c].innerHTML = cell.innerHTML;
      }));
      const range = this.cells[this.row][this.column];
      const text = this.outer.state.doc.sliceString(range.from, range.to);
      if (text !== this.child.state.doc.toString()) {
        this.syncing = true;
        try { this.child.dispatch({ changes: { from: 0, to: this.child.state.doc.length, insert: text },
          selection: { anchor: Math.min(this.child.state.selection.main.head, text.length) } }); }
        finally { this.syncing = false; }
      }
    } else { if (old) old.replaceWith(next); else this.dom.append(next); }
    this.dom.querySelectorAll('tr').forEach((row, r) => Array.from(row.children).forEach((cell, c) => {
      const element = cell as HTMLElement; element.dataset.row = String(r); element.dataset.column = String(c);
      element.tabIndex = 0; element.setAttribute('aria-label', `Edit row ${r + 1}, column ${c + 1}`);
    }));
    this.updateTools();
    return true;
  }
  begin(row: number, column: number) {
    if (this.outer.state.readOnly || this.outer.compositionStarted || tableComposing(this.outer)) return;
    const range = this.cells[row]?.[column]; if (!range) return;
    if (this.child && row === this.row && column === this.column) { this.child.focus(); return; }
    this.finish(false); this.row = row; this.column = column;
    const cell = this.dom.querySelectorAll('tr')[row]?.children[column] as HTMLElement;
    if (!cell) return;
    cell.innerHTML = ''; cell.classList.add('editing-cell');
    this.child = new EditorView({ parent: cell, state: EditorState.create({
      doc: this.outer.state.doc.sliceString(range.from, range.to),
      extensions: [
        EditorState.transactionFilter.of(transaction => {
          if (this.syncing) return transaction;
          if (!this.child && transaction.docChanged) return [];
          if (this.outer.state.readOnly && transaction.docChanged && !this.syncing) return [];
          if (!transaction.docChanged) return transaction;
          const text = transaction.newDoc.toString();
          // Multiline input is rejected. The existing table source stays intact.
          if (/[\r\n]/.test(text)) return [];
          let escaped = escapeCellPipes(text);
          const target = this.cells[this.row]?.[this.column];
          // A final backslash must not escape the following column delimiter.
          if (target && this.outer.state.doc.sliceString(target.to, target.to + 1) === '|' &&
            (/\\*$/.exec(escaped)![0].length % 2)) escaped += '\\';
          if (target?.virtual && (!escaped || !this.virtualPatch(escaped))) return [];
          if (escaped === text) return transaction;
          return [transaction, { changes: { from: 0, to: text.length, insert: escaped },
            selection: EditorSelection.cursor(escapeCellPipes(text.slice(0, transaction.newSelection.main.head)).length), sequential: true }];
        }),
        keymap.of([
          { key: 'Mod-z', run: () => this.history(undo) },
          { key: 'Mod-Shift-z', run: () => this.history(redo) },
          { key: 'Mod-y', run: () => this.history(redo) },
          { key: 'Mod-s', run: () => { this.outer.state.facet(tableSaveCommand)?.(); return true; } },
          { key: 'Mod-f', run: () => { this.outer.state.facet(tableFindCommand)?.(); return true; } },
          { key: 'Enter', run: () => this.leave() }, { key: 'Escape', run: () => this.leave() },
          { key: 'Tab', run: () => this.move(1) }, { key: 'Shift-Tab', run: () => this.move(-1) },
          ...defaultKeymap,
        ]),
        EditorView.updateListener.of(update => {
          if (!update.docChanged || this.syncing || activeEditors.get(this.outer) !== this) return;
          const target = this.cells[this.row]?.[this.column];
          if (!target || this.outer.state.readOnly) return;
          const text = update.state.doc.toString(), virtual = target.virtual ? this.virtualPatch(text) : null;
          if (target.virtual && !virtual) return;
          this.outer.dispatch({ changes: virtual?.changes || { from: target.from, to: target.to, insert: text },
            effects: virtual ? tableCellEffect.of(virtual.active) : [],
            annotations: Transaction.userEvent.of('input.table') });
        }),
      ],
    }) });
    activeEditors.set(this.outer, this);
    this.outer.dispatch({ effects: tableCellEffect.of({ from: this.from, to: this.to, row, column,
      cellFrom: range.from, cellTo: range.to }) });
    this.child.focus();
    this.updateTools();
  }
  private virtualPatch(text: string) {
    const table = findTable(this.outer.state, this.from);
    if (!table || !text) return null;
    const read = (a: number, b: number) => this.outer.state.doc.sliceString(a, b);
    const actual = tableCells(table, read), current = editableTableCells(table, read)[this.row]?.[this.column];
    const old = this.cells[this.row]?.[this.column];
    if (!current?.virtual || !old?.virtual || current.from !== old.from) return null;
    const nodes: SyntaxNode[] = [];
    for (let node = table.firstChild; node; node = node.nextSibling)
      if (node.name === 'TableHeader' || node.name === 'TableRow') nodes.push(node);
    const row = nodes[this.row]; if (!row || this.row === 0) return null;
    const prefix = (row.lastChild?.name === 'TableDelimiter' ? '' : '|') +
      Array(this.column - actual[this.row].length + 1).fill(' ').join('|');
    const changes = { from: row.to, insert: prefix + text + ' |' };
    const proposed = this.outer.state.update({ changes });
    const next = findTable(proposed.state, this.from);
    const target = next && tableCells(next, (a, b) => proposed.state.doc.sliceString(a, b))[this.row]?.[this.column];
    const cellFrom = row.to + prefix.length;
    if (!next || !target || cellFrom < target.slotFrom || cellFrom + text.length > target.slotTo) return null;
    return { changes, active: { from: this.from, to: next.to, row: this.row, column: this.column,
      cellFrom, cellTo: cellFrom + text.length } };
  }
  private updateTools() {
    if (!this.tools) return;
    const nested = findTable(this.outer.state, this.from)?.parent?.name !== 'Document';
    this.tools.querySelectorAll<HTMLButtonElement>('button').forEach(button => {
      const header = this.row === 0 && (button.dataset.command === 'row-above' || button.dataset.command === 'delete-row');
      const last = this.cells[0]?.length === 1 && button.dataset.command === 'delete-column';
      button.disabled = nested || this.outer.state.readOnly || header || last;
      button.title = nested ? 'Use Table source for tables inside lists or quotes.' : header ? 'The header row stays in the table.' :
        last ? 'The table needs one column.' : '';
    });
  }
  command(command: TableCommand): boolean {
    if (this.outer.state.readOnly || this.outer.compositionStarted || tableComposing(this.outer)) return false;
    let plan;
    try { plan = tablePlan(this.outer.state, this.from, command, this.row, this.column); }
    catch (error) { this.tools?.setAttribute('aria-label', String(error)); return false; }
    if (!plan.changes.length) return true;
    const transaction = this.outer.state.update({ changes: plan.changes });
    const from = transaction.changes.mapPos(this.from, -1), table = findTable(transaction.state, from);
    const cells = table ? tableCells(table, (a, b) => transaction.state.doc.sliceString(a, b)) : [];
    const target = cells[plan.row]?.[plan.column];
    if (!table || !target) return false;
    this.finish(false);
    this.outer.dispatch({ changes: plan.changes,
      effects: [tableCellEffect.of({ from, to: table.to, row: plan.row, column: plan.column,
        cellFrom: target.from, cellTo: target.to }), EditorView.scrollIntoView(from)],
      annotations: Transaction.userEvent.of('input.table.structure') });
    const dom = this.outer.dom.querySelector<HTMLElement>(`.preview-table[data-from="${from}"]`);
    if (dom) tableEditor(dom)?.begin(plan.row, plan.column);
    return true;
  }
  private history(command: (view: EditorView) => boolean) {
    if (tableComposing(this.outer)) return true;
    command(this.outer);
    if (this.child) this.child.focus(); else this.outer.focus();
    return true;
  }
  private leave() {
    if (tableComposing(this.outer)) return true;
    const position = this.to < this.outer.state.doc.length ? this.to + 1 : Math.max(0, this.from - 1);
    this.finish(false);
    this.outer.dispatch({ effects: tableCellEffect.of(null), selection: { anchor: position }, scrollIntoView: true });
    this.outer.focus(); return true;
  }
  private move(direction: number) {
    if (tableComposing(this.outer)) return true;
    const positions = this.cells.flatMap((cells, row) => cells.map((_cell, column) => ({ row, column })));
    const index = positions.findIndex(cell => cell.row === this.row && cell.column === this.column);
    const next = positions[index + direction];
    if (next) this.begin(next.row, next.column); else this.leave();
    return true;
  }
  finish(notify = true) {
    const child = this.child; this.child = undefined; child?.destroy();
    if (activeEditors.get(this.outer) === this) activeEditors.delete(this.outer);
    this.dom.querySelector('.editing-cell')?.classList.remove('editing-cell');
    if (child) this.refresh(this.from, this.to, this.source);
    if (notify && child) this.outer.dispatch({ effects: tableCellEffect.of(null) });
  }
  destroy() {
    this.child?.destroy(); this.child = undefined;
    if (activeEditors.get(this.outer) === this) activeEditors.delete(this.outer);
    controllers.delete(this.dom);
  }
}
