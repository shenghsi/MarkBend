import { Compartment, EditorState } from '@codemirror/state';
import { EditorView } from '@codemirror/view';
import { endTableEdit } from './table';
import { savedSource, sourceField } from './source';
import { RecoveryQueue } from './recovery';

export interface DocumentTab {
  id: number;
  state: EditorState;
  path: string;
  baseline: string;
  uncertain: boolean;
  sourceMode: boolean;
  scroll?: ReturnType<EditorView['scrollSnapshot']>;
  recovery?: RecoveryQueue;
  recoverySession?: string;
}

export const tabSource = (tab: DocumentTab) => savedSource(tab.state.field(sourceField));
export const tabDirty = (tab: DocumentTab) => tab.uncertain || tabSource(tab) !== tab.baseline;
export const tabName = (tab: DocumentTab) => tab.path.split(/[\\/]/).pop() || 'Untitled';

// This model owns retained editor states. The caller owns file effects and must
// confirm recovery and host retirement before it removes a tab.
export class DocumentTabs {
  private entries = new Map<number, DocumentTab>();
  private used = new Set<number>();
  private selected: number;
  constructor(initial: DocumentTab, private inputLock: Compartment) {
    this.selected = initial.id; this.add(initial);
  }
  get active(): DocumentTab { return this.entries.get(this.selected)!; }
  get all(): readonly DocumentTab[] { return [...this.entries.values()]; }
  get(id: number): DocumentTab | undefined { return this.entries.get(id); }
  add(tab: DocumentTab) {
    if (!Number.isSafeInteger(tab.id) || tab.id < 0 || this.used.has(tab.id)) throw new Error('Use a new valid document ID.');
    // A transient file-operation lock must not enter retained tab state.
    tab.state = this.unlocked(tab.state);
    this.entries.set(tab.id, tab); this.used.add(tab.id);
  }
  private unlocked(state: EditorState) {
    return state.update({ effects: this.inputLock.reconfigure([]) }).state;
  }
  capture(view: EditorView) {
    this.active.state = this.unlocked(view.state);
    this.active.scroll = view.scrollSnapshot();
  }
  activate(view: EditorView, id: number, allowed: () => boolean, prepare: () => void): boolean {
    const next = this.entries.get(id);
    if (!next || !allowed()) return false;
    if (id === this.selected) return true;
    // Ending the cell is a presentation change. No source/history edit is made.
    if (!endTableEdit(view)) return false;
    prepare(); this.capture(view); this.selected = id;
    view.setState(next.state);
    if (next.scroll) view.dispatch({ effects: next.scroll });
    return true;
  }
  remove(id: number) {
    if (id === this.selected) throw new Error('Select another document before removing this tab.');
    if (!this.entries.delete(id)) throw new Error('This tab is no longer open.');
  }
}

// Activation is manual: arrow keys move focus; Enter/Space use the normal button
// action. This prevents a focus move from changing the document during input.
export function documentTabBar(parent: HTMLElement, select: (id: number) => void, close: (id: number) => void) {
  const bar = document.createElement('div'); bar.className = 'document-tabs';
  const list = document.createElement('div'); list.className = 'document-tab-list';
  list.setAttribute('role', 'tablist'); list.setAttribute('aria-label', 'Documents');
  const closeButton = document.createElement('button'); closeButton.textContent = 'Close tab';
  let active: number | undefined;
  const buttons = new Map<number, HTMLButtonElement>();
  const click = (event: MouseEvent) => {
    const button = (event.target as Element).closest<HTMLButtonElement>('[data-document]');
    if (button && list.contains(button)) select(Number(button.dataset.document));
  };
  const key = (event: KeyboardEvent) => {
    if (event.isComposing || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
    const order = [...buttons.values()], index = order.indexOf(event.target as HTMLButtonElement);
    if (index < 0) return;
    const target = event.key === 'Home' ? 0 : event.key === 'End' ? order.length - 1
      : event.key === 'ArrowRight' ? (index + 1) % order.length
      : event.key === 'ArrowLeft' ? (index + order.length - 1) % order.length : undefined;
    if (target === undefined) return;
    event.preventDefault(); order[target].focus();
  };
  const closeActive = () => { if (active !== undefined) close(active); };
  list.addEventListener('click', click); list.addEventListener('keydown', key);
  closeButton.addEventListener('click', closeActive); bar.append(list, closeButton); parent.append(bar);
  return {
    render(tabs: DocumentTabs) {
      active = tabs.active.id;
      const current = new Set(tabs.all.map(tab => tab.id));
      for (const [id, button] of buttons) if (!current.has(id)) { button.remove(); buttons.delete(id); }
      for (const tab of tabs.all) {
        let button = buttons.get(tab.id);
        if (!button) {
          button = document.createElement('button'); button.type = 'button'; button.setAttribute('role', 'tab');
          button.id = `document-tab-${tab.id}`; button.setAttribute('aria-controls', 'editor');
          button.dataset.document = String(tab.id); buttons.set(tab.id, button); list.append(button);
        }
        button.textContent = `${tabName(tab)}${tabDirty(tab) ? ' • Unsaved' : ''}${tab.uncertain ? ' • Check Save' : ''}`;
        button.title = tab.path || 'Untitled'; button.setAttribute('aria-selected', String(tab.id === active));
        button.tabIndex = tab.id === active ? 0 : -1;
      }
      closeButton.setAttribute('aria-label', `Close ${tabName(tabs.active)}`);
    },
    destroy() {
      list.removeEventListener('click', click); list.removeEventListener('keydown', key);
      closeButton.removeEventListener('click', closeActive); bar.remove(); buttons.clear();
    },
  };
}
