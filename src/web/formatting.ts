import { EditorSelection } from '@codemirror/state';
import { ensureSyntaxTree } from '@codemirror/language';
import { EditorView } from '@codemirror/view';
import { SyntaxNode } from '@lezer/common';
import { tableCellField, tableComposing } from './table';

export type Format = 'bold' | 'italic' | 'code' | 'paragraph' | `h${1 | 2 | 3 | 4 | 5 | 6}`;
export function format(view: EditorView, kind: Format): string | null {
  const state = view.state;
  if (view.compositionStarted || tableComposing(view)) return 'Finish text input, then apply formatting.';
  if (state.readOnly) return 'The document is read-only.';
  if (state.field(tableCellField, false)) return 'End the table cell edit before you format document text.';
  if (state.selection.ranges.length !== 1) return 'Use one selection for formatting.';
  const selection = state.selection.main, tree = ensureSyntaxTree(state, selection.to, 50);
  if (!tree) return 'Wait for Markdown parsing, then repeat the format command.';
  let block: SyntaxNode | null = tree.resolveInner(selection.from, 1);
  while (block) {
    if (['FencedCode', 'CodeBlock', 'HTMLBlock', 'Table'].includes(block.name)) return 'Edit this block as source.';
    if (block.name === 'InlineCode' && (kind === 'bold' || kind === 'italic')) return 'Code text does not use emphasis marks.';
    block = block.parent;
  }
  if (kind === 'paragraph' || /^h[1-6]$/.test(kind)) {
    const line = state.doc.lineAt(selection.from);
    const last = state.doc.lineAt(selection.to > selection.from && state.doc.lineAt(selection.to).from === selection.to ? selection.to - 1 : selection.to);
    if (last.number !== line.number) return 'Select one line to change its heading level.';
    let heading: SyntaxNode | null = null, container = false;
    tree.iterate({ from: line.from, to: line.to, enter(ref) {
      if (['Blockquote', 'ListItem', 'FencedCode', 'CodeBlock', 'HTMLBlock', 'Table'].includes(ref.name)) container = true;
      if (/^(ATXHeading[1-6]|SetextHeading[12])$/.test(ref.name)) heading = ref.node;
    } });
    if (container) return 'Heading commands currently require a top-level line.';
    const prefix = kind === 'paragraph' ? '' : '#'.repeat(Number(kind.slice(1))) + ' ';
    const changes: { from: number; to?: number; insert: string }[] = [];
    const node = heading as SyntaxNode | null;
    if (node?.name.startsWith('SetextHeading')) {
      const markerLine = state.doc.lineAt(node.lastChild!.from);
      if (state.doc.lineAt(node.from).number !== line.number || markerLine.number !== line.number + 1)
        return 'Select the text line of a single-line underlined heading.';
      changes.push({ from: node.from, insert: prefix }, markerLine.to < state.doc.length
        ? { from: markerLine.from, to: markerLine.to + 1, insert: '' }
        : { from: line.to, to: node.to, insert: '' });
    } else if (node) {
      const first = node.firstChild!, tail = node.lastChild!;
      let end = first.to;
      while (end < line.to && /[ \t]/.test(state.doc.sliceString(end, end + 1))) end++;
      changes.push({ from: node.from, to: end, insert: prefix });
      if (tail.name === 'HeaderMark' && tail.from !== first.from) {
        let start = tail.from;
        while (start > end && /[ \t]/.test(state.doc.sliceString(start - 1, start))) start--;
        changes.push({ from: start, to: tail.to, insert: '' });
      }
    } else {
      if (!line.text.trim()) return 'Type heading text first.';
      changes.push({ from: line.from + /^ {0,3}/.exec(line.text)![0].length, insert: prefix });
    }
    const transaction = state.update({ changes, userEvent: 'input.format' });
    if (transaction.docChanged) view.dispatch(transaction);
    view.focus(); return null;
  }
  let { from, to } = selection;
  if (state.doc.sliceString(from, to).includes('\n')) return 'Select text on one line for inline formatting.';
  const type = { bold: 'StrongEmphasis', italic: 'Emphasis', code: 'InlineCode' }[kind as 'bold' | 'italic' | 'code'];
  let span: SyntaxNode | null = null;
  tree.iterate({ from, to, enter(ref) {
    if (ref.name === type && ref.from <= from && ref.to >= to) span = ref.node;
  } });
  const node = span as SyntaxNode | null;
  if (node) {
    const first = node.firstChild!, last = node.lastChild!;
    let left = first.to, right = last.from;
    const content = state.doc.sliceString(left, right);
    if (kind === 'code' && content.startsWith(' ') && content.endsWith(' ') && /[^ ]/.test(content)) { left++; right--; }
    view.dispatch({ changes: [{ from: first.from, to: left }, { from: right, to: last.to }], userEvent: 'input.format' });
    view.focus(); return null;
  }
  let text = state.doc.sliceString(from, to), mark = kind === 'bold' ? '**' : '*', padding = '';
  if (kind === 'code') {
    mark = '`'.repeat(Math.max(0, ...Array.from(text.matchAll(/`+/g), match => match[0].length)) + 1);
    if (text.startsWith('`') || text.endsWith('`') || /^ .* $/.test(text) && /[^ ]/.test(text)) padding = ' ';
  } else if (text) {
    const leading = /^\s*/.exec(text)![0].length, trailing = /\s*$/.exec(text)![0].length;
    if (leading === text.length) return 'Select text with visible characters.';
    from += leading; to -= trailing; text = state.doc.sliceString(from, to);
  }
  const marks = kind === 'code' ? [mark] : [mark, kind === 'bold' ? '__' : '_'];
  for (const delimiter of marks) {
    const prefix = delimiter + padding, insert = prefix + text + padding + delimiter;
    const transaction = state.update({ changes: { from, to, insert },
      selection: selection.anchor <= selection.head ? EditorSelection.range(from + prefix.length, to + prefix.length)
        : EditorSelection.range(to + prefix.length, from + prefix.length), userEvent: 'input.format' });
    let valid = !text;
    if (text) {
      const candidate = ensureSyntaxTree(transaction.state, from + insert.length, 50);
      candidate?.iterate({ from, to: from + insert.length, enter(ref) {
        if (ref.name === type && ref.from === from && ref.to === from + insert.length) valid = true;
      } });
    }
    if (valid) { view.dispatch(transaction); view.focus(); return null; }
  }
  return 'This selection cannot use these Markdown marks.';
}
