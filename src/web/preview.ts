import { EditorState, Range, StateField } from '@codemirror/state';
import { syntaxTree } from '@codemirror/language';
import { Decoration, DecorationSet, EditorView, WidgetType } from '@codemirror/view';
import { Tree, SyntaxNode } from '@lezer/common';
import { mathRanges } from './math-ranges';
import { htmlFrame, mountResult, renderDiagram, renderedMarkdown, renderedTable } from './renderers';

type Kind = 'math' | 'mermaid' | 'html' | 'table';
interface Item { from: number; to: number; kind?: Kind; source?: string; block?: boolean;
  className?: string; hide?: { from: number; to: number }[]; line?: boolean }
interface Plan { tree: Tree; items: Item[]; decorations: DecorationSet }

export function selected(state: EditorState, from: number, to: number) {
  return state.selection.ranges.some(range => range.from <= to && range.to >= from);
}

class PreviewWidget extends WidgetType {
  constructor(readonly item: Item) { super(); }
  eq(other: PreviewWidget) {
    return this.item.from === other.item.from && this.item.to === other.item.to &&
      this.item.kind === other.item.kind && this.item.source === other.item.source && this.item.block === other.item.block;
  }
  toDOM(view: EditorView): HTMLElement {
    const { item } = this;
    const dom = document.createElement(item.block ? 'div' : 'span');
    dom.className = `preview-widget preview-${item.kind}`;
    dom.dataset.from = String(item.from); dom.dataset.to = String(item.to);
    dom.tabIndex = 0; dom.setAttribute('role', 'button');
    dom.setAttribute('aria-label', `Edit ${item.kind} source`);
    const reveal = () => {
      if (view.compositionStarted || view.state.readOnly) return;
      view.dispatch({ selection: { anchor: item.from }, scrollIntoView: true }); view.focus();
    };
    dom.addEventListener('mousedown', event => { event.preventDefault(); reveal(); });
    dom.addEventListener('click', event => event.preventDefault());
    dom.addEventListener('keydown', event => {
      const key = (event as KeyboardEvent).key;
      if (key === 'Enter' || key === ' ') { event.preventDefault(); reveal(); }
    });
    if (item.kind === 'html') {
      const frame = document.createElement('iframe'); frame.title = 'HTML preview';
      frame.setAttribute('sandbox', ''); frame.srcdoc = htmlFrame(item.source!);
      frame.tabIndex = -1; dom.append(frame);
      const label = document.createElement('span'); label.className = 'preview-caption'; label.textContent = 'HTML · select to edit'; dom.append(label);
    } else if (item.kind === 'table') dom.innerHTML = renderedTable(item.source!);
    else {
      dom.textContent = 'Rendering…';
      const promise = item.kind === 'math' ? import('./math-renderer').then(module => module.renderMath(item.source!, !!item.block))
        : renderDiagram(item.source!);
      cancellations.set(dom, mountResult(dom, promise, () => view.requestMeasure()));
    }
    return dom;
  }
  destroy(dom: HTMLElement) { cancellations.get(dom)?.(); cancellations.delete(dom); }
  get estimatedHeight() { return this.item.block ? (this.item.kind === 'html' ? 200 : 100) : -1; }
}
const cancellations = new WeakMap<HTMLElement, () => void>();

function children(node: SyntaxNode) {
  const result: SyntaxNode[] = [];
  for (let child = node.firstChild; child; child = child.nextSibling) result.push(child);
  return result;
}

function collect(state: EditorState, tree: Tree): Item[] {
  const items: Item[] = [];
  const read = (from: number, to: number) => state.doc.sliceString(from, to);
  tree.iterate({ enter(ref) {
    const node = ref.node, { from, to, name } = node;
    if (name === 'FencedCode') {
      const info = children(node).find(child => child.name === 'CodeInfo');
      const language = info ? read(info.from, info.to).trim().split(/\s/)[0] : '';
      const code = children(node).find(child => child.name === 'CodeText');
      if (language === 'mermaid' || language === 'math' || language === 'latex') {
        items.push({ from, to, kind: language === 'mermaid' ? 'mermaid' : 'math', source: code ? read(code.from, code.to) : '', block: true });
      } else {
        const marks = children(node).filter(child => child.name === 'CodeMark' || child.name === 'CodeInfo');
        items.push({ from, to, className: 'md-code-block', hide: marks.map(child => ({ from: child.from, to: child.to })) });
      }
      return false;
    }
    if (name === 'HTMLBlock' || name === 'Table') {
      items.push({ from, to, kind: name === 'Table' ? 'table' : 'html', source: read(from, to), block: true }); return false;
    }
    if (name === 'Paragraph' || /^ATXHeading/.test(name) || name === 'SetextHeading') {
      const source = read(from, to);
      if (children(node).some(child => child.name === 'HTMLTag')) {
        items.push({ from, to, kind: 'html', source: renderedMarkdown(source), block: true }); return false;
      }
      if (source.includes('$')) for (const math of mathRanges(source)) {
        items.push({ from: from + math.from, to: from + math.to, kind: 'math', source: math.formula, block: math.block });
      }
      const level = /^ATXHeading(\d)$/.exec(name)?.[1] || (name === 'SetextHeading' ? '2' : '');
      if (level) items.push({ from, to, className: `md-heading md-h${level}`, line: true,
        hide: children(node).filter(child => child.name === 'HeaderMark').map(child => ({ from: child.from, to: child.to })) });
    }
    const className = ({ StrongEmphasis: 'md-strong', Emphasis: 'md-emphasis', Strikethrough: 'md-strike', InlineCode: 'md-code', Link: 'md-link' } as Record<string, string>)[name];
    if (className) items.push({ from, to, className,
      hide: children(node).filter(child => /^(EmphasisMark|StrikethroughMark|CodeMark|LinkMark|URL|LinkTitle)$/.test(child.name)).map(child => ({ from: child.from, to: child.to })) });
  } });
  return items;
}

function decorate(state: EditorState, items: Item[]): DecorationSet {
  const ranges: Range<Decoration>[] = [];
  const replacements: { from: number; to: number }[] = [];
  for (const item of items) {
    if (item.kind) {
      if (!selected(state, item.from, item.to) && item.to > item.from) {
        ranges.push(Decoration.replace({ widget: new PreviewWidget(item), block: !!item.block }).range(item.from, item.to));
        replacements.push(item);
      }
    } else if (item.className) {
      if (item.line) ranges.push(Decoration.line({ class: item.className }).range(state.doc.lineAt(item.from).from));
      else ranges.push(Decoration.mark({ class: item.className }).range(item.from, item.to));
      if (!selected(state, item.from, item.to)) for (const hide of item.hide || []) {
        if (hide.to > hide.from) ranges.push(Decoration.replace({}).range(hide.from, hide.to));
      }
    }
  }
  // A math replacement must not overlap hidden Markdown marks inside its source.
  replacements.sort((a, b) => a.from - b.from);
  const insideReplacement = (from: number, to: number) => {
    let low = 0, high = replacements.length;
    while (low < high) { const middle = (low + high) >> 1;
      if (replacements[middle].from <= from) low = middle + 1; else high = middle; }
    return low > 0 && to <= replacements[low - 1].to;
  };
  return Decoration.set(ranges.filter(range => range.value.spec.widget || !insideReplacement(range.from, range.to)), true);
}

export const previewField = StateField.define<Plan>({
  create(state) { const tree = syntaxTree(state), items = collect(state, tree); return { tree, items, decorations: decorate(state, items) }; },
  update(plan, transaction) {
    const tree = syntaxTree(transaction.state);
    if (!transaction.docChanged && !transaction.selection && tree === plan.tree) return plan;
    const items = transaction.docChanged || tree !== plan.tree ? collect(transaction.state, tree) : plan.items;
    return { tree, items, decorations: decorate(transaction.state, items) };
  },
  provide: field => EditorView.decorations.from(field, plan => plan.decorations),
});
export const livePreview = [previewField];
