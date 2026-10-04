import { EditorState, StateField, Text, Transaction } from '@codemirror/state';
import { syntaxTree } from '@codemirror/language';
import { fromMarkdown } from 'mdast-util-from-markdown';
import { gfmFootnote } from 'micromark-extension-gfm-footnote';
import { gfmFootnoteFromMarkdown } from 'mdast-util-gfm-footnote';
import { math } from 'micromark-extension-math';
import { mathFromMarkdown } from 'mdast-util-math';
import { toHast } from 'mdast-util-to-hast';
import { toHtml } from 'hast-util-to-html';
import DOMPurify from 'dompurify';
import type { Root, RootContent, FootnoteDefinition } from 'mdast';

interface Span { from: number; to: number }
export interface NoteDefinition extends Span { identifier: string; label: string; number?: number; duplicate: boolean; node: FootnoteDefinition }
export interface NoteReference extends Span { identifier: string; label: string; number: number }
export interface Footnotes { bodyFrom: number; definitions: NoteDefinition[]; references: NoteReference[]; plainText: Span[] }
const cache = new WeakMap<Text, Map<number, Footnotes>>();

function parse(state: EditorState, fresh = false): Footnotes {
  const bodyFrom = syntaxTree(state).topNode.getChild('Frontmatter')?.to || 0;
  let entries = cache.get(state.doc);
  const previous = entries?.get(bodyFrom); if (!fresh && previous) return previous;
  const result: Footnotes = { bodyFrom, definitions: [], references: [], plainText: [] };
  const source = state.doc.sliceString(bodyFrom);
  if (source.includes('[^')) {
    const tree = fromMarkdown(source, { extensions: [gfmFootnote(), math()], mdastExtensions: [gfmFootnoteFromMarkdown(), mathFromMarkdown()] });
    const accepted = new Map<string, NoteDefinition>(), calls: { node: Extract<RootContent, { type: 'footnoteReference' }>; from: number; to: number }[] = [];
    function visit(node: Root | RootContent, protectedText = false) {
      const from = bodyFrom + (node.position?.start.offset || 0), to = bodyFrom + (node.position?.end.offset || 0);
      if (node.type === 'footnoteDefinition') {
        const definition: NoteDefinition = { from, to, identifier: node.identifier, label: node.label || node.identifier,
          duplicate: accepted.has(node.identifier), node };
        result.definitions.push(definition);
        if (!definition.duplicate) accepted.set(node.identifier, definition);
        return; // Nested definition content belongs to this source range.
      }
      if (node.type === 'footnoteReference') calls.push({ node, from, to });
      else if (node.type === 'text') {
        const raw = source.slice(from - bodyFrom, to - bodyFrom);
        if (!protectedText && raw === node.value && !/[\[\]\\<>$&]/.test(raw)) result.plainText.push({ from, to });
      }
      else if ('children' in node) for (const child of node.children)
        visit(child, protectedText || ['link', 'linkReference', 'image', 'imageReference'].includes(node.type));
    }
    visit(tree);
    let number = 0;
    for (const call of calls) {
      const definition = accepted.get(call.node.identifier); if (!definition) continue;
      definition.number ??= ++number;
      result.references.push({ from: call.from, to: call.to, identifier: call.node.identifier,
        label: call.node.label || call.node.identifier, number: definition.number });
    }
  }
  if (fresh) return result;
  if (!entries) { entries = new Map(); cache.set(state.doc, entries); }
  entries.set(bodyFrom, result); return result;
}

const proseText = /^[\p{L}\p{N}\p{M} \t]*$/u;
const wordCharacter = /^[\p{L}\p{N}\p{M}]$/u;
function neighbour(state: EditorState, position: number, before: boolean): Span & { text: string } {
  // Read at most two UTF-16 units, then retain one complete code point.
  const source = before ? state.sliceDoc(Math.max(0, position - 2), position)
    : state.sliceDoc(position, Math.min(state.doc.length, position + 2));
  const points = Array.from(source), text = (before ? points[points.length - 1] : points[0]) || '';
  return { from: before ? position - text.length : position, to: before ? position : position + text.length, text };
}

// Guarded prose edits preserve complete word characters on both sides.
function mapPlainText(value: Footnotes, transaction: Transaction): Footnotes | undefined {
  const { startState, state, changes } = transaction;
  if ((syntaxTree(state).topNode.getChild('Frontmatter')?.to || 0) !== value.bodyFrom || !value.plainText.length) return;
  const edits: { from: number; to: number; insert: string }[] = [];
  changes.iterChanges((from, to, _a, _b, insert) => edits.push({ from, to, insert: insert.toString() }));
  for (const edit of edits) {
    if (!proseText.test(edit.insert) || !proseText.test(startState.sliceDoc(edit.from, edit.to))) return;
    let low = 0, high = value.plainText.length;
    while (low < high) { const middle = (low + high) >> 1; if (value.plainText[middle].from < edit.from) low = middle + 1; else high = middle; }
    const span = value.plainText[low - 1];
    if (!span || edit.to >= span.to) return;
    // Preserve both complete word code points across all changes.
    const neighbours = [neighbour(startState, edit.from, true), neighbour(startState, edit.to, false)];
    if (!neighbours.every(point => wordCharacter.test(point.text) && !edits.some(change =>
      overlaps(point, change) || (change.from === change.to && change.from > point.from && change.from < point.to)))) return;
    // Removing letters between digits can create an ordered-list marker.
    if (neighbours.every(point => /^[0-9]$/.test(point.text))) return;
    const line = startState.doc.lineAt(edit.from);
    if (edit.to > line.to) return;
    // The protected neighbours leave word text on this physical line.
  }
  if (edits.every(edit => edit.insert.length === edit.to - edit.from)) return value;
  const map = <T extends Span>(span: T): T => ({ ...span, from: changes.mapPos(span.from, 1), to: changes.mapPos(span.to, -1) });
  const bodyFrom = changes.mapPos(value.bodyFrom, -1);
  const definitions = value.definitions.map(note => {
    const mapped = map(note); if (mapped.from === note.from && mapped.to === note.to) return note;
    const node = structuredClone(note.node);
    function positions(child: Root | RootContent) {
      if (child.position) for (const edge of ['start', 'end'] as const) {
        const point = child.position[edge]; if (point.offset == null) continue;
        const absolute = changes.mapPos(value.bodyFrom + point.offset, edge === 'start' ? 1 : -1);
        const line = state.doc.lineAt(absolute), first = state.doc.lineAt(bodyFrom);
        point.offset = absolute - bodyFrom; point.line = line.number - first.number + 1;
        point.column = absolute - (line.number === first.number ? bodyFrom : line.from) + 1;
      }
      if ('children' in child) for (const nested of child.children) positions(nested);
    }
    positions(node); return { ...mapped, node };
  });
  return { bodyFrom, definitions, references: value.references.map(map), plainText: value.plainText.map(map) };
}

export const footnoteField = StateField.define<Footnotes>({
  create: state => parse(state),
  update(value, transaction) {
    if (transaction.docChanged) return mapPlainText(value, transaction) || parse(transaction.state);
    return (syntaxTree(transaction.state).topNode.getChild('Frontmatter')?.to || 0) !== value.bodyFrom ? parse(transaction.state) : value;
  },
});
export const freshFootnotes = (state: EditorState) => parse(state, true);
export const footnotes = (state: EditorState) => state.field(footnoteField, false) || parse(state);
export const overlaps = (a: Span, b: Span) => a.from < b.to && a.to > b.from;
export function footnoteSource(state: EditorState, from: number, to = from) {
  const model = footnotes(state);
  return model.definitions.some(note => from <= note.to && to >= note.from) ||
    model.references.some(note => from === to ? from >= note.from && from <= note.to : overlaps({ from, to }, note));
}
export function definitionAt(state: EditorState, position: number) {
  return footnotes(state).definitions.some(note => position >= note.from && position <= note.to);
}

export function renderFootnote(definition: NoteDefinition): string {
  const root: Root = { type: 'root', children: definition.node.children };
  const tree = toHast(root, { allowDangerousHtml: false, handlers: {
    html: (_state, node) => ({ type: 'text', value: node.value }),
    image: (_state, node) => ({ type: 'text', value: node.alt || '' }),
    imageReference: (_state, node) => ({ type: 'text', value: node.alt || '' }),
    link: (state, node) => ({ type: 'element', tagName: 'span', properties: {}, children: state.all(node) }),
    linkReference: (state, node) => ({ type: 'element', tagName: 'span', properties: {}, children: state.all(node) }),
    footnoteReference: (_state, node) => ({ type: 'text', value: `[^${node.label || node.identifier}]` }),
    footnoteDefinition: (state, node) => ({ type: 'element', tagName: 'div', properties: {}, children: state.all(node) }),
    math: (_state, node) => ({ type: 'element', tagName: 'div', properties: { className: ['footnote-math'], dataDisplay: 'true' },
      children: [{ type: 'text', value: `$$\n${node.value}\n$$` }] }),
    inlineMath: (_state, node) => ({ type: 'element', tagName: 'span', properties: { className: ['footnote-math'], dataDisplay: 'false' },
      children: [{ type: 'text', value: `$${node.value}$` }] }),
  } });
  return DOMPurify.sanitize(toHtml(tree!), { FORBID_TAGS: ['script', 'style', 'a', 'img', 'iframe', 'object', 'embed', 'form', 'input', 'button'],
    FORBID_ATTR: ['style', 'id', 'name', 'href', 'src', 'srcset', 'action', 'formaction'] });
}
