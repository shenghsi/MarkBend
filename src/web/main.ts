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
import './style.css';

document.querySelector('#app')!.innerHTML = `<header><strong>MarkBend</strong><button id="new">New</button><button id="open">Open</button><button id="save">Save</button><button id="save-as">Save As</button><button id="undo">Undo</button><button id="redo">Redo</button><button id="source" aria-pressed="false">Source</button><button id="check">Check Save</button><span id="status" role="status"></span></header><main id="editor"></main>`;
const status = document.querySelector<HTMLElement>('#status')!;
let path = '', baseline = '', uncertain = false, busy = false;
const inputLock = new Compartment();
const display = new Compartment();
let sourceMode = false;
const text = () => savedSource(view.state.field(sourceField));
const dirty = () => text() !== baseline;
const report = () => { status.textContent = `${path.split(/[\\/]/).pop() || 'Untitled'}${dirty() ? ' • Unsaved' : ''}`; };
const state = (source: string) => EditorState.create({ doc: normalize(fromSource(source).raw), extensions: [
  sourceExtensions(fromSource(source)), history(), highlightActiveLine(), inputLock.of([]),
  markdown({ base: markdownLanguage, codeLanguages: languages }), syntaxHighlighting(defaultHighlightStyle), EditorView.lineWrapping,
  display.of(sourceMode ? [lineNumbers()] : livePreview),
  keymap.of([{ key: 'Enter', run: bendReturn }, { key: 'Mod-s', run: () => { void operation(saveFile); return true; } }, ...defaultKeymap, ...historyKeymap]),
  EditorView.updateListener.of(update => { if (update.docChanged) report(); }),
] });
export const view = new EditorView({ state: state(''), parent: document.querySelector('#editor')! });
report(); view.focus();
async function operation(action: () => Promise<void>, lock = false) {
  if (!canUseFiles(busy, view.compositionStarted)) {
    if (view.compositionStarted) status.textContent = 'Finish text input, then repeat the file command.';
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
document.querySelector('#undo')!.addEventListener('click', () => { undo(view); view.focus(); });
document.querySelector('#redo')!.addEventListener('click', () => { redo(view); view.focus(); });
document.querySelector('#source')!.addEventListener('click', () => {
  if (view.compositionStarted) { status.textContent = 'Finish text input, then change the display.'; return; }
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
