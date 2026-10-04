import { Compartment, EditorState } from '@codemirror/state';
import { EditorView, keymap, lineNumbers, highlightActiveLine } from '@codemirror/view';
import { defaultKeymap, history, historyKeymap, undo, redo } from '@codemirror/commands';
import { markdown, markdownLanguage } from '@codemirror/lang-markdown';
import { languages } from '@codemirror/language-data';
import { defaultHighlightStyle, syntaxHighlighting } from '@codemirror/language';
import { invoke, isTauri } from '@tauri-apps/api/core';
import { open, save, ask } from '@tauri-apps/plugin-dialog';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { fromSource, normalize, savedSource, sourceExtensions, sourceField } from './source';
import { bendReturn } from './commands';
import { canUseFiles } from './file-guard';
import { livePreview } from './preview';
import { tableComposing, tableSaveCommand, tableFindCommand } from './table';
import { find, guardedSearchKeymap, outline, searchSupport } from './navigation';
import { format, Format } from './formatting';
import './style.css';

document.querySelector('#app')!.innerHTML = `<header><strong>MarkBend</strong><button id="new">New</button><button id="open">Open</button><button id="save">Save</button><button id="save-as">Save As</button><button id="undo">Undo</button><button id="redo">Redo</button><button id="find">Find</button><button id="outline-toggle" aria-pressed="false">Outline</button><button id="source" aria-pressed="false">Source</button><button id="check">Check Save</button><span id="status" role="status"></span></header><div class="workspace"><aside id="outline" aria-label="Outline" hidden></aside><main id="editor"></main></div>`;
const outlinePane = document.querySelector<HTMLElement>('#outline')!;
const formatBar = document.createElement('div');
formatBar.className = 'format-bar'; formatBar.setAttribute('role', 'toolbar'); formatBar.setAttribute('aria-label', 'Formatting');
formatBar.innerHTML = `<button data-format="bold">Bold</button><button data-format="italic">Italic</button><button data-format="code">Code</button><select id="heading" aria-label="Heading level"><option value="">Heading…</option><option value="paragraph">Paragraph</option>${Array.from({ length: 6 }, (_, index) => `<option value="h${index + 1}">Heading ${index + 1}</option>`).join('')}</select>`;
document.querySelector('header')!.after(formatBar);
const status = document.querySelector<HTMLElement>('#status')!;
let path = '', baseline = '', uncertain = false, busy = false;
const inputLock = new Compartment();
const display = new Compartment();
let sourceMode = false;
const text = () => savedSource(view.state.field(sourceField));
const dirty = () => text() !== baseline;
const report = () => { status.textContent = `${path.split(/[\\/]/).pop() || 'Untitled'}${dirty() ? ' • Unsaved' : ''}`; };
function applyFormat(kind: Format) { const reason = format(view, kind); if (reason) status.textContent = reason; return true; }
const formattingKeys = [
  { key: 'Mod-b', run: () => applyFormat('bold') }, { key: 'Mod-i', run: () => applyFormat('italic') },
  { key: 'Mod-Shift-c', run: () => applyFormat('code') },
  ...Array.from({ length: 6 }, (_, index) => ({ key: `Mod-Alt-${index + 1}`, run: () => applyFormat(`h${index + 1}` as Format) })),
];
const state = (source: string): EditorState => EditorState.create({ doc: normalize(fromSource(source).raw), extensions: [
  sourceExtensions(fromSource(source)), history(), highlightActiveLine(), inputLock.of([]),
  markdown({ base: markdownLanguage, codeLanguages: languages }), syntaxHighlighting(defaultHighlightStyle), EditorView.lineWrapping,
  display.of(sourceMode ? [lineNumbers()] : livePreview),
  tableSaveCommand.of(() => { void operation(saveFile); }),
  tableFindCommand.of(() => { find(view); }), searchSupport(() => view), outline(outlinePane),
  keymap.of([...guardedSearchKeymap, ...formattingKeys, { key: 'Enter', run: bendReturn }, { key: 'Mod-s', run: () => { void operation(saveFile); return true; } }, ...defaultKeymap, ...historyKeymap]),
  EditorView.updateListener.of(update => { if (update.docChanged) report(); }),
] });
export const view: EditorView = new EditorView({ state: state(''), parent: document.querySelector('#editor')! });
report(); view.focus();
formatBar.querySelectorAll<HTMLButtonElement>('[data-format]').forEach(button => {
  button.addEventListener('mousedown', event => event.preventDefault());
  button.addEventListener('click', () => applyFormat(button.dataset.format as Format));
});
formatBar.querySelector<HTMLSelectElement>('#heading')!.addEventListener('change', event => {
  const select = event.target as HTMLSelectElement;
  if (select.value) applyFormat(select.value as Format); select.value = '';
});
async function operation(action: () => Promise<void>, lock = false) {
  const composing = view.compositionStarted || tableComposing(view);
  if (!canUseFiles(busy, composing)) {
    if (composing) status.textContent = 'Finish text input, then repeat the file command.';
    return;
  }
  busy = true;
  if (lock) view.dispatch({ effects: inputLock.reconfigure([EditorState.readOnly.of(true), EditorView.editable.of(false)]) });
  try { await action(); } catch (error) { status.textContent = typeof error === 'object' && error && 'message' in error ? String(error.message) : String(error); }
  finally { busy = false; if (lock) view.dispatch({ effects: inputLock.reconfigure([]) }); view.focus(); }
}
async function discard() {
  if (uncertain) throw new Error('Check the last save before you close or open a file.');
  return !dirty() || await ask('Discard the unsaved changes?', { title: 'MarkBend', kind: 'warning' });
}
async function saveFile(as = false) {
  if (uncertain) throw new Error('Check the last save before you save again.');
  if (!isTauri()) throw new Error('Open the desktop app to use file commands.');
  const destination = !as && path ? path : await save({ defaultPath: path || 'Untitled.md', filters: [{ name: 'Markdown', extensions: ['md', 'markdown'] }] });
  if (!destination) return;
  const captured = text();
  try { await invoke('save_document', { path: destination, source: captured }); }
  catch (error) {
    if (typeof error === 'object' && error && 'uncertain' in error && error.uncertain) {
      uncertain = true; path = destination; baseline = captured;
      throw new Error(`Save completion is uncertain. Use Check Save. ${'message' in error ? error.message : ''}`);
    }
    throw error;
  }
  path = destination; baseline = captured; report();
}
document.querySelector('#new')!.addEventListener('click', () => void operation(async () => {
  if (await discard()) {
    if (isTauri()) await invoke('new_document');
    path = ''; baseline = ''; view.setState(state('')); report(); view.focus();
  }
}, true));
document.querySelector('#open')!.addEventListener('click', () => void operation(async () => {
  if (!isTauri()) throw new Error('Open the desktop app to use file commands.');
  if (!await discard()) return;
  const selected = await open({ multiple: false, filters: [{ name: 'Markdown', extensions: ['md', 'markdown', 'txt'] }] });
  if (!selected) return;
  const loaded = await invoke<{ source: string; path: string }>('open_document', { path: selected });
  path = loaded.path; baseline = loaded.source; view.setState(state(loaded.source)); report(); view.focus();
}, true));
document.querySelector('#save')!.addEventListener('click', () => void operation(saveFile));
document.querySelector('#save-as')!.addEventListener('click', () => void operation(() => saveFile(true)));
document.querySelector('#undo')!.addEventListener('click', () => { if (!view.compositionStarted && !tableComposing(view)) { undo(view); view.focus(); } });
document.querySelector('#redo')!.addEventListener('click', () => { if (!view.compositionStarted && !tableComposing(view)) { redo(view); view.focus(); } });
document.querySelector('#find')!.addEventListener('click', () => {
  if (!find(view)) status.textContent = 'Finish text input, then open Find.';
});
document.querySelector('#outline-toggle')!.addEventListener('click', () => {
  if (view.compositionStarted || tableComposing(view)) return;
  outlinePane.hidden = !outlinePane.hidden;
  document.querySelector('#outline-toggle')!.setAttribute('aria-pressed', String(!outlinePane.hidden));
  view.requestMeasure();
});
document.querySelector('#source')!.addEventListener('click', () => {
  if (view.compositionStarted || tableComposing(view)) { status.textContent = 'Finish text input, then change the display.'; return; }
  sourceMode = !sourceMode;
  document.querySelector('#source')!.setAttribute('aria-pressed', String(sourceMode));
  document.querySelector('#editor')!.classList.toggle('source-mode', sourceMode);
  view.dispatch({ effects: display.reconfigure(sourceMode ? [lineNumbers()] : livePreview) }); view.focus();
});
document.querySelector('#check')!.addEventListener('click', () => void operation(async () => { await invoke('check_save'); uncertain = false; report(); }));
if (isTauri()) void getCurrentWindow().onCloseRequested(async event => {
  event.preventDefault(); if (busy) return;
  await operation(async () => { if (await discard()) await getCurrentWindow().destroy(); });
});
