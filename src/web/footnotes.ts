import { EditorState, StateField, Text } from '@codemirror/state';
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
export interface Footnotes { bodyFrom: number; definitions: NoteDefinition[]; references: NoteReference[] }
const cache = new WeakMap<Text, Map<number, Footnotes>>();

function parse(state: EditorState): Footnotes {
  const bodyFrom = syntaxTree(state).topNode.getChild('Frontmatter')?.to || 0;
  let entries = cache.get(state.doc);
  const previous = entries?.get(bodyFrom); if (previous) return previous;
  const result: Footnotes = { bodyFrom, definitions: [], references: [] };
  const source = state.doc.sliceString(bodyFrom);
  if (source.includes('[^')) {
    const tree = fromMarkdown(source, { extensions: [gfmFootnote(), math()], mdastExtensions: [gfmFootnoteFromMarkdown(), mathFromMarkdown()] });
    const accepted = new Map<string, NoteDefinition>(), calls: { node: Extract<RootContent, { type: 'footnoteReference' }>; from: number; to: number }[] = [];
    function visit(node: Root | RootContent) {
      const from = bodyFrom + (node.position?.start.offset || 0), to = bodyFrom + (node.position?.end.offset || 0);
      if (node.type === 'footnoteDefinition') {
        const definition: NoteDefinition = { from, to, identifier: node.identifier, label: node.label || node.identifier,
          duplicate: accepted.has(node.identifier), node };
        result.definitions.push(definition);
        if (!definition.duplicate) accepted.set(node.identifier, definition);
        return; // Nested definition content belongs to this source range.
      }
      if (node.type === 'footnoteReference') calls.push({ node, from, to });
      else if ('children' in node) for (const child of node.children) visit(child);
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
  if (!entries) { entries = new Map(); cache.set(state.doc, entries); }
  entries.set(bodyFrom, result); return result;
}

export const footnoteField = StateField.define<Footnotes>({
  create: parse,
  update(value, transaction) {
    return transaction.docChanged || (syntaxTree(transaction.state).topNode.getChild('Frontmatter')?.to || 0) !== value.bodyFrom ? parse(transaction.state) : value;
  },
});
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
    math: (_state, node) => ({ type: 'text', value: `$$\n${node.value}\n$$` }),
    inlineMath: (_state, node) => ({ type: 'text', value: `$${node.value}$` }),
  } });
  return DOMPurify.sanitize(toHtml(tree!), { FORBID_TAGS: ['script', 'style', 'a', 'img', 'iframe', 'object', 'embed', 'form', 'input', 'button'],
    FORBID_ATTR: ['style', 'id', 'name', 'href', 'src', 'srcset', 'action', 'formaction'] });
}
