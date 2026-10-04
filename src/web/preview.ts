import { EditorState, Range, StateField } from '@codemirror/state';
import { syntaxTree } from '@codemirror/language';
import { Decoration, DecorationSet, EditorView, WidgetType } from '@codemirror/view';
import { Tree, SyntaxNode } from '@lezer/common';
import { mathRanges } from './math-ranges';
import { htmlFrame, mountResult, renderDiagram, renderedMarkdown } from './renderers';
import { TableEditor, tableCellField, tableComposing, tableEditor } from './table';
import { blockItems, Marker, MarkerWidget } from './block-preview';
import { imagePath, imageReader, ImageInfo, mountImage, setImagePath } from './images';

type Kind = 'math' | 'mermaid' | 'html' | 'table' | 'image' | 'frontmatter';
interface Item { from: number; to: number; kind?: Kind; source?: string; block?: boolean;
  className?: string; hide?: { from: number; to: number }[]; line?: boolean; style?: string; marker?: Marker; image?: ImageInfo; imageVersion?: number }
interface Plan { tree: Tree; items: Item[]; decorations: DecorationSet; imagePath: string; imageVersion: number }

export function selected(state: EditorState, from: number, to: number) {
  return state.selection.ranges.some(range => range.from <= to && range.to >= from);
}

class PreviewWidget extends WidgetType {
  constructor(readonly item: Item) { super(); }
  eq(other: PreviewWidget) {
    return this.item.from === other.item.from && this.item.to === other.item.to &&
      this.item.kind === other.item.kind && this.item.source === other.item.source && this.item.block === other.item.block &&
      JSON.stringify(this.item.image) === JSON.stringify(other.item.image) && this.item.imageVersion === other.item.imageVersion;
  }
  updateDOM(dom: HTMLElement, view: EditorView) {
    if (this.item.kind !== 'table') return false;
    dom.dataset.from = String(this.item.from); dom.dataset.to = String(this.item.to);
    return tableEditor(dom)?.refresh(this.item.from, this.item.to, this.item.source!) || false;
  }
  toDOM(view: EditorView): HTMLElement {
    const { item } = this;
    const dom = document.createElement(item.block ? 'div' : 'span');
    dom.className = `preview-widget preview-${item.kind}`;
    dom.dataset.from = String(item.from); dom.dataset.to = String(item.to);
    dom.tabIndex = item.kind === 'table' ? -1 : 0; dom.setAttribute('role', item.kind === 'table' ? 'group' : 'button');
    dom.setAttribute('aria-label', item.kind === 'table' ? 'Editable table' : `Edit ${item.kind === 'frontmatter' ? 'front matter' : item.kind} source`);
    const reveal = () => {
      if (view.compositionStarted || tableComposing(view) || view.state.readOnly) return;
      tableEditor(dom)?.finish();
      view.dispatch({ selection: { anchor: Number(dom.dataset.from) }, scrollIntoView: true }); view.focus();
    };
    dom.addEventListener('mousedown', event => {
      if (item.kind === 'table' && (event.target as HTMLElement).closest('th, td, .table-source, .table-tools')) return;
      event.preventDefault(); reveal();
    });
    dom.addEventListener('click', event => event.preventDefault());
    dom.addEventListener('keydown', event => {
      if (event.defaultPrevented) return;
      if (item.kind === 'table' && (event.target as HTMLElement).closest('th, td, .table-tools')) return;
      const key = (event as KeyboardEvent).key;
      if (key === 'Enter' || key === ' ') { event.preventDefault(); reveal(); }
    });
    if (item.kind === 'frontmatter') {
      const caption = document.createElement('span'); caption.className = 'preview-caption'; caption.textContent = 'Front matter · select to edit';
      const source = document.createElement('pre'); source.textContent = item.source!; dom.append(caption, source);
    } else if (item.kind === 'image') cancellations.set(dom, mountImage(dom, item.image!, () => view.requestMeasure()));
    else if (item.kind === 'html') {
      const frame = document.createElement('iframe'); frame.title = 'HTML preview';
      frame.setAttribute('sandbox', ''); frame.srcdoc = htmlFrame(item.source!);
      frame.tabIndex = -1; dom.append(frame);
      const label = document.createElement('span'); label.className = 'preview-caption'; label.textContent = 'HTML · select to edit'; dom.append(label);
    } else if (item.kind === 'table') new TableEditor(dom, view, item.from, item.to, item.source!);
    else {
      dom.textContent = 'Rendering…';
      const promise = item.kind === 'math' ? import('./math-renderer').then(module => module.renderMath(item.source!, !!item.block))
        : renderDiagram(item.source!);
      cancellations.set(dom, mountResult(dom, promise, () => view.requestMeasure()));
    }
    return dom;
  }
  destroy(dom: HTMLElement) { tableEditor(dom)?.destroy(); cancellations.get(dom)?.(); cancellations.delete(dom); }
  get estimatedHeight() { return this.item.block ? (this.item.kind === 'html' ? 200 : 100) : -1; }
}
const cancellations = new WeakMap<HTMLElement, () => void>();

function children(node: SyntaxNode) {
  const result: SyntaxNode[] = [];
  for (let child = node.firstChild; child; child = child.nextSibling) result.push(child);
  return result;
}

function collect(state: EditorState, tree: Tree, imageVersion = 0): Item[] {
  const items: Item[] = blockItems(state, tree);
  const read = (from: number, to: number) => state.doc.sliceString(from, to);
  const bodyFrom = tree.topNode.getChild('Frontmatter')?.to || 0;
  const readImage = imageReader(() => state.doc.sliceString(bodyFrom), state.field(imagePath, false) || '');
  tree.iterate({ enter(ref) {
    const node = ref.node, { from, to, name } = node;
    if (name === 'Frontmatter') {
      if (to > from) items.push({ from, to, className: 'md-frontmatter-source' });
      if (children(node).filter(child => child.name === 'DashLine').length === 2)
        items.push({ from, to, kind: 'frontmatter', source: read(from, to), block: true });
      return false;
    }
    if (name === 'Image') {
      if (items.some(item => item.kind === 'math' && item.from <= from && item.to >= to)) return false;
      const image = readImage(read(from, to));
      if (image) items.push({ from, to, kind: 'image', image, imageVersion });
      return false;
    }
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
    if (name === 'Paragraph' || /^ATXHeading/.test(name) || /^SetextHeading/.test(name)) {
      const source = read(from, to);
      if (children(node).some(child => child.name === 'HTMLTag')) {
        items.push({ from, to, kind: 'html', source: renderedMarkdown(source), block: true }); return false;
      }
      if (source.includes('$')) for (const math of mathRanges(source)) {
        items.push({ from: from + math.from, to: from + math.to, kind: 'math', source: math.formula, block: math.block });
      }
      const level = /^(?:ATXHeading|SetextHeading)(\d)$/.exec(name)?.[1] || '';
      if (level) items.push({ from, to, className: `md-heading md-h${level}`, line: true,
        hide: children(node).filter(child => child.name === 'HeaderMark').map(child => ({ from: child.from, to: child.to })) });
    }
    const className = ({ StrongEmphasis: 'md-strong', Emphasis: 'md-emphasis', Strikethrough: 'md-strike', InlineCode: 'md-code', Link: 'md-link' } as Record<string, string>)[name];
    if (className) items.push({ from, to, className,
      hide: children(node).filter(child => /^(EmphasisMark|StrikethroughMark|CodeMark|LinkMark|LinkLabel|URL|LinkTitle)$/.test(child.name)).map(child => ({ from: child.from, to: child.to })) });
  } });
  return items;
}

function decorate(state: EditorState, items: Item[]): DecorationSet {
  const ranges: Range<Decoration>[] = [];
  const replacements: { from: number; to: number }[] = [];
  for (const item of items) {
    if (item.marker) {
      if (!selected(state, item.marker.ownerFrom, item.marker.ownerTo))
        ranges.push(Decoration.replace({ widget: new MarkerWidget(item.marker) }).range(item.from, item.to));
    } else if (item.kind) {
      const active = state.field(tableCellField, false);
      const editing = item.kind === 'table' && active?.from === item.from && active.to === item.to;
      if ((!selected(state, item.from, item.to) || editing) && item.to > item.from) {
        ranges.push(Decoration.replace({ widget: new PreviewWidget(item), block: !!item.block }).range(item.from, item.to));
        replacements.push(item);
      }
    } else {
      if (item.line) ranges.push(Decoration.line({ attributes: { class: item.className!, ...(item.style ? { style: item.style } : {}) } }).range(state.doc.lineAt(item.from).from));
      else if (item.className) ranges.push(Decoration.mark({ class: item.className }).range(item.from, item.to));
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
  create(state) { const tree = syntaxTree(state), items = collect(state, tree); return { tree, items, decorations: decorate(state, items), imagePath: state.field(imagePath, false) || '', imageVersion: 0 }; },
  update(plan, transaction) {
    const tree = syntaxTree(transaction.state);
    const path = transaction.state.field(imagePath, false) || '', pathChanged = path !== plan.imagePath || transaction.effects.some(effect => effect.is(setImagePath));
    if (!transaction.docChanged && !transaction.selection && tree === plan.tree &&
      !pathChanged && transaction.startState.field(tableCellField, false) === transaction.state.field(tableCellField, false)) return plan;
    const imageVersion = plan.imageVersion + (pathChanged ? 1 : 0);
    const items = transaction.docChanged || tree !== plan.tree || pathChanged ? collect(transaction.state, tree, imageVersion) : plan.items;
    return { tree, items, decorations: decorate(transaction.state, items), imagePath: path, imageVersion };
  },
  provide: field => EditorView.decorations.from(field, plan => plan.decorations),
});
export const livePreview = [tableCellField, previewField];
