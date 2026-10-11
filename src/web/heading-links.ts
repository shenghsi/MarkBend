import { EditorState } from '@codemirror/state';
import { EditorView, keymap } from '@codemirror/view';
import { ensureSyntaxTree } from '@codemirror/language';
import { documentImageEnvironment } from './renderers';
import { footnotes, overlaps } from './footnotes';
import { tableCellField, tableComposing } from './table';

// Return a source target, an explicit failure, or undefined outside a link.
export function headingLinkTarget(state: EditorState, position: number): number | string | undefined {
  const selection = state.selection;
  if (selection.ranges.length !== 1) return 'Use one selection to follow a heading link.';
  const tree = ensureSyntaxTree(state, state.doc.length, 50);
  if (!tree) return 'Wait for Markdown parsing, then follow the heading link.';
  let node = tree.resolveInner(position, 1);
  while (!['Link', 'Autolink'].includes(node.name) && node.parent) node = node.parent;
  if (!['Link', 'Autolink'].includes(node.name)) return;
  const range = { from: node.from, to: node.to };
  for (let parent = node.parent; parent; parent = parent.parent)
    if (['FencedCode', 'CodeBlock', 'HTMLBlock', 'Table', 'Frontmatter', 'Image'].includes(parent.name)) return;
  if (footnotes(state).definitions.some(note => overlaps(note, range))) return;
  if (!selection.main.empty && (selection.main.from < node.from || selection.main.to > node.to))
    return 'Keep the selection inside one heading link.';
  const bodyFrom = tree.topNode.getChild('Frontmatter')?.to || 0;
  const environment = documentImageEnvironment(state.doc, bodyFrom);
  const destination = environment.links?.get(`${node.from - bodyFrom}:${node.to - bodyFrom}`);
  if (destination === undefined) return 'This link has no accepted Markdown destination.';
  if (!destination.startsWith('#')) return 'This command follows heading links in this document.';
  let fragment: string;
  try { fragment = decodeURIComponent(destination.slice(1)); }
  catch { return 'The heading link has an invalid percent escape.'; }
  if (!fragment) return bodyFrom;
  const target = environment.headingTargets?.get(fragment);
  if (!target) return 'The heading link target was not found.';
  const from = bodyFrom + target.from, to = bodyFrom + target.to;
  let heading = tree.resolveInner(from, 1);
  while (!/^(ATXHeading[1-6]|SetextHeading[12])$/.test(heading.name) && heading.parent) heading = heading.parent;
  if (heading.from !== from || heading.to !== to || !/^(ATXHeading[1-6]|SetextHeading[12])$/.test(heading.name))
    return 'The Markdown parsers do not agree on this heading.';
  return from;
}

export function followHeadingLink(view: EditorView, position: number, report: (message: string) => void,
  blocked: () => string | null = () => null) {
  const reason = blocked() || (view.compositionStarted || tableComposing(view) ? 'Finish text input, then follow the heading link.' :
    view.state.field(tableCellField, false) ? 'End the table cell edit, then follow the heading link.' : null);
  if (reason) { report(reason); return true; }
  const target = headingLinkTarget(view.state, position);
  if (target === undefined) return false;
  if (typeof target === 'string') { report(target); return true; }
  view.dispatch({ selection: { anchor: target }, effects: EditorView.scrollIntoView(target, { y: 'start' }) });
  view.focus(); report('Moved to the heading link target.'); return true;
}

export function headingLinks(report: (message: string) => void, blocked: () => string | null = () => null) {
  return [keymap.of([{ key: 'Mod-Enter', run: view => followHeadingLink(view, view.state.selection.main.head, report, blocked) }]),
    EditorView.domEventHandlers({ mousedown(event, view) {
      const mod = /Mac|iPhone|iPad|iPod/.test(navigator.platform) ? event.metaKey : event.ctrlKey;
      if (event.defaultPrevented || event.button !== 0 || !mod || event.altKey || event.shiftKey ||
        !(event.target instanceof Element) || event.target.closest('.preview-widget') || !view.contentDOM.contains(event.target)) return false;
      const position = view.posAtCoords({ x: event.clientX, y: event.clientY });
      if (position === null) return false;
      const result = followHeadingLink(view, position, report, blocked);
      if (result) event.preventDefault(); return result;
    } })];
}
