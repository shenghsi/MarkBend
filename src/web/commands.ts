import commands from './generated/commands.mjs';
import { EditorView } from '@codemirror/view';
import { ensureSyntaxTree } from '@codemirror/language';
import { insertNewlineContinueMarkupCommand } from '@codemirror/lang-markdown';
import { tableComposing } from './table';
import { sourceOffset, restoreSource, sourceField, viewOffset } from './source';
import { definitionAt } from './footnotes';

export function bendReturn(view: EditorView): boolean {
  if (view.compositionStarted || view.state.readOnly || view.state.selection.ranges.length !== 1) return false;
  const record = view.state.field(sourceField), selection = view.state.selection.main;
  const doc = view.state.doc.toString();
  const edit = commands.return_edit(doc, selection.from, selection.to);
  const scalarOffset = (position: bigint) => Array.from(doc).slice(0, Number(position)).join('').length;
  const from = scalarOffset(edit.start), to = scalarOffset(edit.end);
  const line = view.state.doc.lineAt(selection.from);
  const previous = record.raw.slice(0, sourceOffset(record, line.from)).match(/\r\n|\r|\n/g);
  const ending = /^(\r\n|\r|\n)/.exec(record.raw.slice(sourceOffset(record, line.to)))?.[0] || previous?.at(-1) || '\n';
  const rawText = edit.text.replace(/\n/g, ending);
  const start = sourceOffset(record, from), end = sourceOffset(record, to);
  const raw = record.raw.slice(0, start) + rawText + record.raw.slice(end);
  view.dispatch({ changes: { from, to, insert: edit.text },
    selection: { anchor: viewOffset(raw, start + rawText.length) },
    effects: restoreSource.of({ ...record, raw }), userEvent: 'input' });
  return true;
}

const continueMarkup = insertNewlineContinueMarkupCommand({ nonTightLists: false });
export function markdownReturn(view: EditorView): boolean {
  if (view.compositionStarted || tableComposing(view) || view.state.readOnly || view.state.selection.ranges.length !== 1) return false;
  const { state } = view, selection = state.selection.main;
  const plain = () => {
    view.dispatch(state.update(state.replaceSelection('\n'), { scrollIntoView: true, userEvent: 'input' }));
    return true;
  };
  if (definitionAt(state, selection.from)) return plain();
  // Complete the tree before asking the package to continue a container.
  const tree = ensureSyntaxTree(state, state.doc.length, 50);
  if (!tree) return plain();
  let items = 0, container = false, continuation = false;
  const line = state.doc.lineAt(selection.from);
  for (let node = tree.resolveInner(selection.from, -1); node; node = node.parent!) {
    if (['FencedCode', 'CodeBlock', 'HTMLBlock', 'Table', 'Frontmatter'].includes(node.name)) return plain();
    if (node.name === 'Blockquote') container = true;
    if (node.name === 'ListItem') { items++; if (node.from < line.from) continuation = true; }
  }
  if (container || items > 1 || continuation) return continueMarkup(view) || plain();
  return bendReturn(view);
}
