import { EditorSelection, EditorState, Facet, StateEffect, StateField, Text, Transaction } from '@codemirror/state';
import { EditorView, keymap } from '@codemirror/view';
import { defaultKeymap, invertedEffects, isolateHistory, redo, undo } from '@codemirror/commands';
import { syntaxTree, ensureSyntaxTree } from '@codemirror/language';
import { SyntaxNode } from '@lezer/common';
import { tableImageEnvironment, tableProjection } from './renderers';
import { imageDocument, imagePath, mountImage, setImagePath } from './images';
import { mountFormula } from './math-preview';
import { clipboardImageFiles, imagePasteMessage, imagePasteGuard, clipboardVersion, clipboardRequest, clipboardRaster, readClipboardRaster, clipboardSourceLimit } from './clipboard';
import { sourceField, savedSource, rawOffset } from './source';
import { cellImageRange, cellPasteContext } from './table-paste';
import { Cell, tableCells, editableTableCells } from './table-ranges';
import { findTable, tablePlan, TableCommand } from './table-commands';
export { tableCells } from './table-ranges';

export const tableImageVersion = StateField.define<number>({
  create: () => 0,
  update: (version, transaction) => version + (transaction.docChanged ||
    transaction.effects.some(effect => effect.is(setImagePath)) ||
    transaction.startState.field(imagePath, false) !== transaction.state.field(imagePath, false) ||
    transaction.startState.facet(imageDocument) !== transaction.state.facet(imageDocument) ? 1 : 0),
});
const environments = new WeakMap<Text, { bodyFrom: number; value: ReturnType<typeof tableImageEnvironment> }>();
function imageEnvironment(state: EditorState, source: string) {
  if (!source.includes('[')) return {};
  const bodyFrom = syntaxTree(state).topNode.getChild('Frontmatter')?.to || 0;
  const old = environments.get(state.doc);
  if (old?.bodyFrom === bodyFrom) return old.value;
  const value = tableImageEnvironment(state.doc.sliceString(bodyFrom));
  environments.set(state.doc, { bodyFrom, value }); return value;
}

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
export const tableInputView = (view: EditorView) => activeEditors.get(view)?.child;
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
  private results = new Map<HTMLElement, (() => void)[]>();
  private releaseResults(cell?: HTMLElement) {
    for (const [target, disposers] of this.results) if (!cell || cell === target) {
      disposers.forEach(dispose => dispose()); this.results.delete(target);
    }
  }
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
    const renderSource = renderRows.join('\n');
    const projection = tableProjection(renderSource, imageEnvironment(this.outer.state, renderSource),
      this.outer.state.field(imagePath, false) || '', this.outer.state.facet(imageDocument));
    const fresh = document.createElement('div'); fresh.innerHTML = projection.html;
    const old = this.dom.querySelector('table'), next = fresh.querySelector('table');
    if (!next) return false;
    const oldRows = old?.querySelectorAll('tr'), newRows = next.querySelectorAll('tr');
    if (this.child && (!oldRows || oldRows.length !== newRows.length ||
      Array.from(newRows).some((row, index) => row.children.length !== oldRows[index].children.length) ||
      !this.cells[this.row]?.[this.column])) return false;
    if (this.child && old) {
      newRows.forEach((row, r) => Array.from(row.children).forEach((cell, c) => {
        if (r !== this.row || c !== this.column) {
          const target = oldRows![r].children[c] as HTMLElement;
          this.releaseResults(target); target.innerHTML = cell.innerHTML;
        }
      }));
      const range = this.cells[this.row][this.column];
      const text = this.outer.state.doc.sliceString(range.from, range.to);
      if (text !== this.child.state.doc.toString()) {
        this.syncing = true;
        try { this.child.dispatch({ changes: { from: 0, to: this.child.state.doc.length, insert: text },
          selection: { anchor: Math.min(this.child.state.selection.main.head, text.length) } }); }
        finally { this.syncing = false; }
      }
    } else { this.releaseResults(); if (old) old.replaceWith(next); else this.dom.append(next); }
    this.dom.querySelectorAll('tr').forEach((row, r) => Array.from(row.children).forEach((cell, c) => {
      const element = cell as HTMLElement; element.dataset.row = String(r); element.dataset.column = String(c);
      element.tabIndex = 0; element.setAttribute('aria-label', `Edit row ${r + 1}, column ${c + 1}`);
      if (this.child && r === this.row && c === this.column) return;
      const disposers: (() => void)[] = [];
      element.querySelectorAll<HTMLElement>('[data-table-image]').forEach(slot => {
        const image = projection.images[Number(slot.dataset.tableImage)];
        if (image) disposers.push(mountImage(slot, image, () => this.outer.requestMeasure()));
      });
      element.querySelectorAll<HTMLElement>('[data-table-math]').forEach(slot => {
        const formula = projection.formulas[Number(slot.dataset.tableMath)];
        if (formula) disposers.push(mountFormula(slot, formula, () => this.outer.requestMeasure()));
      });
      if (disposers.length) this.results.set(element, disposers);
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
    this.releaseResults(cell);
    cell.innerHTML = ''; cell.classList.add('editing-cell');
    this.child = new EditorView({ parent: cell, state: EditorState.create({
      doc: this.outer.state.doc.sliceString(range.from, range.to),
      extensions: [
        EditorView.domEventHandlers({ paste: event => {
          if (!clipboardImageFiles(event.clipboardData)) return false;
          event.preventDefault();
          this.pasteImage(event);
          return true;
        } }),
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
            annotations: [Transaction.userEvent.of('input.table'),
              ...(update.transactions.some(transaction => transaction.isUserEvent('input.drop')) ? [isolateHistory.of('full')] : [])] });
        }),
      ],
    }) });
    activeEditors.set(this.outer, this);
    this.outer.dispatch({ effects: tableCellEffect.of({ from: this.from, to: this.to, row, column,
      cellFrom: range.from, cellTo: range.to }) });
    this.child.focus();
    this.updateTools();
  }
  private pasteImage(event: ClipboardEvent) {
    const report = this.outer.state.facet(imagePasteMessage) || (() => {}), requestCurrent = clipboardRequest(this.outer);
    const child = this.child, files = clipboardImageFiles(event.clipboardData)!;
    const guard = () => this.outer.state.facet(imagePasteGuard)() ||
      (this.outer.state.readOnly || child?.state.readOnly ? 'The document is read-only.' :
        this.outer.compositionStarted || child?.compositionStarted ? 'Finish text input, then paste the image.' :
          child?.state.selection.ranges.length !== 1 ? 'Use one selection for image paste.' : null);
    const reason = guard(); if (reason) { report(reason); return; }
    if (!child) return;
    const file = clipboardRaster(files); if (typeof file === 'string') { report(file); return; }
    const outerState = this.outer.state, childState = child.state, selection = childState.selection.main;
    const references = imageEnvironment(outerState, this.source);
    if (!cellPasteContext(childState.doc.toString(), selection.from, selection.to, references)) {
      report('Paste the image into table cell text, outside code, math, links, and image syntax.'); return;
    }
    const version = outerState.field(clipboardVersion, false), row = this.row, column = this.column;
    const current = () => requestCurrent() && this.child === child && activeEditors.get(this.outer) === this
      && this.row === row && this.column === column && child.state === childState
      && this.outer.state.field(clipboardVersion, false) === version
      && (version !== undefined || this.outer.state === outerState)
      && this.outer.state.doc === outerState.doc && this.outer.state.field(sourceField) === outerState.field(sourceField)
      && this.outer.state.facet(imageDocument) === outerState.facet(imageDocument)
      && this.outer.state.field(imagePath, false) === outerState.field(imagePath, false);
    const prepare = (destination: string) => {
      const inserted = `![](<${destination}>)`, from = escapeCellPipes(childState.doc.sliceString(0, selection.from)).length;
      const transaction = childState.update({ changes: { from: selection.from, to: selection.to, insert: inserted },
        selection: { anchor: selection.from + inserted.length }, userEvent: 'input.paste' });
      const text = transaction.newDoc.toString();
      if (!transaction.docChanged || !cellImageRange(text, from, from + inserted.length, destination, references))
        throw new Error('Paste the image into table cell text, outside code, math, links, and image syntax.');
      const target = this.cells[row]?.[column], virtual = target?.virtual ? this.virtualPatch(text) : null;
      if (!target || target.virtual && !virtual) throw new Error('The table cell changed. Paste the image again.');
      const outer = outerState.update({ changes: virtual?.changes || { from: target.from, to: target.to, insert: text },
        effects: virtual ? tableCellEffect.of(virtual.active) : [], userEvent: 'input.table' });
      return { transaction, bytes: new TextEncoder().encode(savedSource(outer.state.field(sourceField))).length };
    };
    try {
      const stub = `![](<data:${file.type};base64,>)`;
      const preview = escapeCellPipes(childState.doc.sliceString(0, selection.from) + stub + childState.doc.sliceString(selection.to));
      const target = this.cells[row][column], changes = target.virtual ? this.virtualChanges(preview) : { from: target.from, to: target.to, insert: preview };
      if (!changes) throw new Error('The table cell changed. Paste the image again.');
      const record = outerState.field(sourceField), proposed = { ...record, raw: record.raw.slice(0, rawOffset(record.raw, changes.from))
        + changes.insert + record.raw.slice(rawOffset(record.raw, 'to' in changes ? changes.to : changes.from)) };
      if (new TextEncoder().encode(savedSource(proposed)).length + Math.ceil(file.size / 3) * 4 > clipboardSourceLimit)
        throw new Error('The clipboard image does not fit the 8 MiB document limit.');
      const projected = prepare(`data:${file.type};base64,`);
      if (projected.bytes + Math.ceil(file.size / 3) * 4 > clipboardSourceLimit) throw new Error('The clipboard image does not fit the 8 MiB document limit.');
    } catch (error) { report(String(error)); return; }
    report('Reading clipboard image…');
    void readClipboardRaster(file).then(destination => {
      if (!current()) {
        if (requestCurrent() && this.child === child) report('The document or selection changed. Paste the image again.');
        return;
      }
      const reason = guard(); if (reason) { report(reason); return; }
      const planned = prepare(destination);
      if (planned.bytes > clipboardSourceLimit) throw new Error('The clipboard image does not fit the 8 MiB document limit.');
      child.dispatch(planned.transaction); child.focus(); report('Image pasted.');
    }).catch(error => { if (current()) report(`Cannot paste image: ${String(error)}`); });
  }
  imageDrop(target: Element, point: { x: number; y: number }, destination: string) {
    const cell = target.closest<HTMLElement>('th, td');
    if (!cell || cell.closest('.preview-table') !== this.dom) return 'Drop into a table cell.';
    const row = Number(cell.dataset.row), column = Number(cell.dataset.column), range = this.cells[row]?.[column];
    if (!range) return 'The table cell changed. Drop the image again.';
    const outerState = this.outer.state, capturedChild = this.child, childState = capturedChild?.state;
    const capturedActive = activeEditors.get(this.outer), activeChild = capturedActive?.child, activeState = activeChild?.state;
    const active = !!capturedChild && this.row === row && this.column === column;
    const child = active ? capturedChild : undefined;
    if (child && (!child.contentDOM.contains(target) || target.closest('.cm-content') !== child.contentDOM))
      return 'Drop into the table cell text.';
    const textBefore = child?.state.doc.toString() ?? outerState.doc.sliceString(range.from, range.to);
    const at = child ? child.posAtCoords(point) : textBefore.length;
    if (at === null) return 'Drop into visible table cell text.';
    const guard = () => this.outer.state.readOnly || capturedChild?.state.readOnly ? 'The document is read-only.' :
      this.outer.compositionStarted || tableComposing(this.outer) ? 'Finish text input, then drop the image.' :
        child && child.state.selection.ranges.length !== 1 ? 'Use one selection for image drop.' : null;
    const reason = guard(); if (reason) return reason;
    const references = imageEnvironment(outerState, this.source);
    if (!cellPasteContext(textBefore, at, at, references)) return 'Drop outside code, math, links, and image syntax.';
    // A rendered cell has no exact character map. Append with a separator;
    // an active raw cell instead uses its actual drop position.
    const separator = !child && textBefore && !/\s$/.test(textBefore) ? ' ' : '';
    const rawDestination = destination.replace(/&/g, '&amp;').replace(/\\/g, '\\\\');
    const image = `![](<${rawDestination}>)`, inserted = separator + image;
    let text = escapeCellPipes(textBefore.slice(0, at) + inserted + textBefore.slice(at));
    if (outerState.doc.sliceString(range.to, range.to + 1) === '|' && /\\*$/.exec(text)![0].length % 2) text += '\\';
    const changes = range.virtual ? this.virtualChanges(text, row, column) : { from: range.from, to: range.to, insert: text };
    if (!changes) return 'The table cell changed. Drop the image again.';
    const record = outerState.field(sourceField), proposed = { ...record, raw: record.raw.slice(0, rawOffset(record.raw, changes.from))
      + changes.insert + record.raw.slice(rawOffset(record.raw, 'to' in changes ? changes.to : changes.from)) };
    if (new TextEncoder().encode(savedSource(proposed)).length > clipboardSourceLimit) return 'The image path does not fit the 8 MiB document limit.';
    const from = escapeCellPipes(textBefore.slice(0, at)).length + separator.length;
    if (!cellImageRange(text, from, from + image.length, destination, references)) return 'Drop outside code, math, links, and image syntax.';
    const transaction = child?.state.update({ changes: { from: at, insert: inserted }, selection: { anchor: at + inserted.length }, userEvent: 'input.drop' });
    if (transaction && (!transaction.docChanged || transaction.newDoc.toString() !== text)) return 'The table cell changed. Drop the image again.';
    const virtual = range.virtual ? this.virtualPatch(text, row, column) : null;
    if (range.virtual && !virtual) return 'The table cell changed. Drop the image again.';
    const outer = outerState.update({ changes: virtual?.changes || changes,
      effects: virtual ? tableCellEffect.of(virtual.active) : child ? [] : tableCellEffect.of(null),
      annotations: isolateHistory.of('full'), userEvent: 'input.table' });
    if (new TextEncoder().encode(savedSource(outer.state.field(sourceField))).length > clipboardSourceLimit)
      return 'The image path does not fit the 8 MiB document limit.';
    const previousRow = this.row, previousColumn = this.column, rect = cell.getBoundingClientRect();
    const childScroll = capturedChild && [capturedChild.scrollDOM.scrollLeft, capturedChild.scrollDOM.scrollTop];
    const current = () => {
      const next = cell.getBoundingClientRect();
      return this.outer.state === outerState && controllers.get(this.dom) === this && cell.isConnected
        && this.dom.contains(cell) && this.cells[row]?.[column] === range && this.child === capturedChild
        && capturedChild?.state === childState && this.row === previousRow && this.column === previousColumn
        && activeEditors.get(this.outer) === capturedActive && capturedActive?.child === activeChild && activeChild?.state === activeState
        && (!capturedChild || capturedChild.scrollDOM.scrollLeft === childScroll![0] && capturedChild.scrollDOM.scrollTop === childScroll![1])
        && next.x === rect.x && next.y === rect.y && next.width === rect.width && next.height === rect.height;
    };
    return { current, guard, apply: () => {
      if (!current() || guard()) return false;
      if (child && transaction) { child.dispatch(transaction); child.focus(); }
      else {
        capturedActive?.finish(false); if (capturedActive !== this) this.finish(false); this.outer.dispatch(outer);
        const dom = this.outer.dom.querySelector<HTMLElement>(`.preview-table[data-from="${this.from}"]`);
        const editor = dom && tableEditor(dom); editor?.begin(row, column);
        if (editor?.child) { editor.child.dispatch({ selection: { anchor: text.length } }); editor.child.focus(); }
      }
      return true;
    } };
  }
  private virtualChanges(text: string, targetRow = this.row, targetColumn = this.column) {
    const table = findTable(this.outer.state, this.from);
    if (!table || !text) return null;
    const read = (a: number, b: number) => this.outer.state.doc.sliceString(a, b);
    const actual = tableCells(table, read), current = editableTableCells(table, read)[targetRow]?.[targetColumn];
    const old = this.cells[targetRow]?.[targetColumn];
    if (!current?.virtual || !old?.virtual || current.from !== old.from) return null;
    const nodes: SyntaxNode[] = [];
    for (let node = table.firstChild; node; node = node.nextSibling)
      if (node.name === 'TableHeader' || node.name === 'TableRow') nodes.push(node);
    const row = nodes[targetRow]; if (!row || targetRow === 0) return null;
    const prefix = (row.lastChild?.name === 'TableDelimiter' ? '' : '|') +
      Array(targetColumn - actual[targetRow].length + 1).fill(' ').join('|');
    return { from: row.to, insert: prefix + text + ' |', cellFrom: row.to + prefix.length };
  }
  private virtualPatch(text: string, row = this.row, column = this.column) {
    const changes = this.virtualChanges(text, row, column); if (!changes) return null;
    const proposed = this.outer.state.update({ changes });
    const tree = ensureSyntaxTree(proposed.state, changes.from + changes.insert.length, 100); if (!tree) return null;
    let next: SyntaxNode | null = tree.resolveInner(this.from, 1);
    while (next && next.name !== 'Table') next = next.parent;
    if (next?.from !== this.from) return null;
    const target = next && tableCells(next, (a, b) => proposed.state.doc.sliceString(a, b))[row]?.[column];
    const cellFrom = changes.cellFrom;
    if (!next || !target || cellFrom < target.slotFrom || cellFrom + text.length > target.slotTo) return null;
    return { changes, active: { from: this.from, to: next.to, row, column,
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
    this.releaseResults();
    this.child?.destroy(); this.child = undefined;
    if (activeEditors.get(this.outer) === this) activeEditors.delete(this.outer);
    controllers.delete(this.dom);
  }
}
