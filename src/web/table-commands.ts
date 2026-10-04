import { ChangeSpec, EditorState } from '@codemirror/state';
import { syntaxTree } from '@codemirror/language';
import { SyntaxNode } from '@lezer/common';
import { Cell, tableCells } from './table-ranges';

export type TableCommand = 'row-above' | 'row-below' | 'delete-row' | 'column-left' | 'column-right' |
  'delete-column' | 'align-left' | 'align-center' | 'align-right';
export interface TablePlan { changes: ChangeSpec[]; row: number; column: number }
interface Row { node: SyntaxNode; cells: Cell[] }

export function findTable(state: EditorState, from: number): SyntaxNode | null {
  let node: SyntaxNode | null = syntaxTree(state).resolveInner(from, 1);
  while (node && node.name !== 'Table') node = node.parent;
  return node?.from === from ? node : null;
}

function rows(state: EditorState, table: SyntaxNode): Row[] {
  const read = (from: number, to: number) => state.doc.sliceString(from, to);
  const cells = tableCells(table, read), result: Row[] = []; let index = 0;
  for (let node = table.firstChild; node; node = node.nextSibling) {
    if (node.name === 'TableHeader' || node.name === 'TableRow') result.push({ node, cells: cells[index++] });
    else if (node.name === 'TableDelimiter') {
      // This row has already been validated as a GFM alignment row by Lezer.
      const source = read(node.from, node.to), slots: Cell[] = []; let start = 0;
      for (let offset = 0; offset <= source.length; offset++) {
        if (offset !== source.length && source[offset] !== '|') continue;
        if (offset > start) {
          const text = source.slice(start, offset), token = /^\s*(:?-+:?)\s*$/.exec(text);
          if (!token) throw new Error('The alignment row has an unsupported slot.');
          const from = node.from + start + /^\s*/.exec(text)![0].length;
          slots.push({ from, to: from + token[1].length, slotFrom: node.from + start, slotTo: node.from + offset });
        }
        start = offset + 1;
      }
      result.push({ node, cells: slots });
    }
  }
  return result;
}

// Each column patch affects one row. Existing slots are copied verbatim;
// only the added/deleted slot or alignment token changes.
function columnPatch(state: EditorState, row: Row, index: number, width: number, remove: boolean) {
  const raw = row.cells.map(cell => state.doc.sliceString(cell.slotFrom, cell.slotTo));
  let leading = state.doc.sliceString(row.node.from, row.cells[0].slotFrom);
  let trailing = state.doc.sliceString(row.cells.at(-1)!.slotTo, row.node.to);
  while (raw.length < width) raw.push(' ');
  if (remove) raw.splice(index, 1); else raw.splice(index, 0,
    row.node.name === 'TableDelimiter' ? (index === 0 && !leading ? '--- ' : ' --- ') :
      row.node.name === 'TableHeader' ? (index === 0 && !leading ? 'Column ' : ' Column ') : ' ');
  // Empty edge cells need outer delimiters so they are not mistaken for them.
  if (/^\s/.test(raw[0]) && !leading) leading = '|';
  if (!raw.at(-1)!.trim() && !trailing) trailing = '|';
  if (raw.length === 1) { leading ||= '|'; trailing ||= '|'; }
  const insert = leading + raw.join('|') + trailing;
  const previous = state.doc.sliceString(row.node.from, row.node.to);
  let from = 0, end = previous.length, newEnd = insert.length;
  while (from < end && from < newEnd && previous[from] === insert[from]) from++;
  while (end > from && newEnd > from && previous[end - 1] === insert[newEnd - 1]) { end--; newEnd--; }
  return { from: row.node.from + from, to: row.node.from + end, insert: insert.slice(from, newEnd) };
}

export function tablePlan(state: EditorState, from: number, command: TableCommand, row: number, column: number): TablePlan {
  const table = findTable(state, from);
  if (!table || table.parent?.name !== 'Document') throw new Error('Use Table source for tables inside lists or quotes.');
  const model = rows(state, table), width = model[0]?.cells.length || 0;
  if (!width || model[1]?.node.name !== 'TableDelimiter' || model[1].cells.length !== width ||
    model.some(item => !item.cells.length)) throw new Error('The table has unsupported source ranges.');
  if (row < 0 || row >= model.length - 1 || column < 0 || column >= width) throw new Error('Select a table cell first.');
  const body = row === 0 ? model[1] : model[row + 1];
  if (command === 'delete-row') {
    if (row === 0) throw new Error('The header row cannot be deleted.');
    const line = state.doc.lineAt(body.node.from);
    return { changes: [{ from: line.from, to: Math.min(line.to + 1, state.doc.length), insert: '' }],
      row: Math.max(0, row - 1), column };
  }
  if (command === 'row-above' || command === 'row-below') {
    if (row === 0 && command === 'row-above') throw new Error('Insert a row below the header.');
    const prefix = state.doc.sliceString(state.doc.lineAt(model[0].node.from).from, model[0].node.from);
    if (!/^ {0,3}$/.test(prefix)) throw new Error('Use Table source for this table prefix.');
    const empty = prefix + '|' + Array(width).fill(' ').join('|') + '|';
    const line = state.doc.lineAt(body.node.from), above = command === 'row-above';
    return { changes: [{ from: above ? line.from : line.to, insert: above ? empty + '\n' : '\n' + empty }],
      row: above ? row : row + 1, column };
  }
  if (command.startsWith('align-')) {
    const cell = model[1].cells[column], token = state.doc.sliceString(cell.from, cell.to);
    const dashes = token.replace(/:/g, '');
    const insert = (command !== 'align-right' ? ':' : '') + dashes + (command !== 'align-left' ? ':' : '');
    return { changes: insert === token ? [] : [{ from: cell.from, to: cell.to, insert }], row, column };
  }
  if (command === 'delete-column' && width === 1) throw new Error('The last column cannot be deleted.');
  const index = column + (command === 'column-right' ? 1 : 0), remove = command === 'delete-column';
  return { changes: model.map(item => columnPatch(state, item, index, width, remove)), row,
    column: remove ? Math.min(column, width - 2) : index };
}
