import { EditorState, StateEffect } from '@codemirror/state';
import { EditorView, ViewPlugin, ViewUpdate } from '@codemirror/view';
import { syntaxTree } from '@codemirror/language';
import { openSearchPanel, search, searchKeymap } from '@codemirror/search';
import MarkdownIt from 'markdown-it';
import { endTableEdit, tableCellEffect, tableComposing } from './table';
import { footnotes, overlaps } from './footnotes';

export const composing = (view: EditorView) => view.compositionStarted || tableComposing(view);
export const find = (view: EditorView) => endTableEdit(view) && openSearchPanel(view);
export const guardedSearchKeymap = searchKeymap.map(binding => ({ ...binding,
  run: binding.run ? (view: EditorView) => endTableEdit(view) ? binding.run!(view) : true : undefined,
  shift: binding.shift ? (view: EditorView) => endTableEdit(view) ? binding.shift!(view) : true : undefined,
}));
export function searchSupport(getView: () => EditorView) {
  const searchAction = (transaction: { isUserEvent(event: string): boolean }) =>
    transaction.isUserEvent('input.replace') || transaction.isUserEvent('select.search');
  return [search({ top: true }), EditorState.transactionFilter.of(transaction =>
    searchAction(transaction) && composing(getView()) ? [] : transaction),
  EditorState.transactionExtender.of(transaction => searchAction(transaction)
    ? { effects: tableCellEffect.of(null) } : null)];
}

export interface Heading { from: number; to: number; level: number; label: string }
const markdown = new MarkdownIt({ html: false });
const headingLabels = new Map<string, string>();
export const refreshOutline = StateEffect.define<null>();
export function headings(state: EditorState): Heading[] {
  const result: Heading[] = [];
  const definitions = footnotes(state).definitions;
  syntaxTree(state).iterate({ enter(node) {
    if (node.name === 'Frontmatter') return false;
    if (definitions.some(note => node.from >= note.from && node.to <= note.to)) return false;
    if (!/^(ATXHeading[1-6]|SetextHeading[12])$/.test(node.name)) return;
    if (definitions.some(note => overlaps(node, note))) return false;
    const source = state.doc.sliceString(node.from, node.to);
    let content = source, level = Number(node.name.slice(-1));
    if (node.name.startsWith('SetextHeading')) {
      const marker = node.node.lastChild!; level = state.doc.sliceString(marker.from, marker.to).trim().startsWith('=') ? 1 : 2;
      content = state.doc.sliceString(node.from, marker.from).trimEnd();
    } else content = source.replace(/^#{1,6}\s*/, '').replace(/\s+#+\s*$/, '');
    let label = headingLabels.get(source);
    if (label === undefined) {
      const tokens = markdown.parseInline(content, {})[0]?.children || [];
      label = tokens.map(token => ['text', 'code_inline', 'image'].includes(token.type) ? token.content :
        token.type === 'softbreak' || token.type === 'hardbreak' ? ' ' : '').join('');
      if (source.length <= 4096) {
        if (headingLabels.size >= 1024) headingLabels.delete(headingLabels.keys().next().value!);
        headingLabels.set(source, label);
      }
    }
    result.push({ from: node.from, to: node.to, level, label: label || 'Untitled heading' });
    return false;
  } });
  return result;
}

export function outline(container: HTMLElement) {
  return ViewPlugin.fromClass(class {
    tree;
    constructor(readonly view: EditorView) { this.tree = syntaxTree(view.state); this.render(); }
    update(update: ViewUpdate) {
      const tree = syntaxTree(update.state);
      if (update.docChanged || tree !== this.tree || update.transactions.some(transaction => transaction.effects.some(effect => effect.is(refreshOutline)))) { this.tree = tree; this.render(); }
    }
    render() {
      if (container.hidden) { container.replaceChildren(); return; }
      const list = document.createElement('ul'); list.setAttribute('aria-label', 'Document headings');
      for (const heading of headings(this.view.state)) {
        const item = document.createElement('li'), button = document.createElement('button');
        button.textContent = heading.label; button.style.paddingLeft = `${12 + (heading.level - 1) * 12}px`;
        button.addEventListener('mousedown', event => event.preventDefault());
        button.addEventListener('click', () => {
          if (!endTableEdit(this.view)) return;
          this.view.dispatch({ selection: { anchor: heading.from }, effects: EditorView.scrollIntoView(heading.from, { y: 'start' }) });
          this.view.focus();
        });
        item.append(button); list.append(item);
      }
      container.replaceChildren(list);
    }
    destroy() { container.replaceChildren(); }
  });
}
