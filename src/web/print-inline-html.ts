import { raw } from 'hast-util-raw';
import type { Element, ElementContent, Root, RootContent } from 'hast';

interface PrintSlot { type: 'printSlot'; key: number }
declare module 'hast' {
  interface ElementContentMap { printSlot: PrintSlot }
  interface RootContentMap { printSlot: PrintSlot }
}

const semantic = new Set(['span', 'b', 'strong', 'i', 'em', 'u', 's', 'del',
  'small', 'sub', 'sup', 'kbd', 'code', 'samp', 'var', 'mark', 'abbr', 'cite',
  'q', 'time', 'br', 'wbr', 'a']);

// Parse a complete phrasing fragment, so opening and closing HTML tags can
// enclose Markdown and controlled renderer slots. Authored HTML cannot create
// a custom HAST node. The upstream parser clones pass-through nodes; private
// keys, complete membership, order, and supported ancestry establish provenance.
export function printInlineHTML(element: Element, controlled: WeakSet<Element>): Element | undefined {
  const slots = new Map<number, Element>();
  function protect(node: ElementContent): ElementContent {
    if (node.type !== 'element') return node;
    if (controlled.has(node) || node.tagName === 'input') {
      const key = slots.size; slots.set(key, node); return { type: 'printSlot', key };
    }
    return { ...node, children: node.children.map(protect) };
  }
  const input: Root = { type: 'root', children: [{ type: 'element', tagName: 'span',
    properties: {}, children: element.children.map(protect) }] };
  let parsed: Root | RootContent;
  try { parsed = raw(input, { passThrough: ['printSlot'] }); } catch { return undefined; }
  if (parsed.type !== 'root' || parsed.children.length !== 1) return undefined;
  const wrapper = parsed.children[0];
  if (wrapper.type !== 'element' || wrapper.tagName !== 'span') return undefined;
  let next = 0;
  function validate(node: ElementContent): boolean {
    if (node.type === 'printSlot') return node.key === next++ && slots.has(node.key);
    if (node.type === 'text') return true;
    if (node.type === 'comment') return true;
    if (node.type !== 'element' || !semantic.has(node.tagName)) return false;
    // No authored classes, IDs, styles, data attributes, resources, or actions
    // enter the application DOM. These three attributes affect text only.
    node.properties = Object.fromEntries(Object.entries(node.properties)
      .filter(([key]) => ['dir', 'lang', 'title'].includes(key)));
    return node.children.every(validate);
  }
  if (!wrapper.children.every(validate) || next !== slots.size) return undefined;
  function expand(node: ElementContent): ElementContent {
    if (node.type === 'printSlot') return slots.get(node.key)!;
    return node.type === 'element' ? { ...node, children: node.children.map(expand) } : node;
  }
  return { ...element, children: wrapper.children.map(expand) };
}
