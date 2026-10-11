import { Compartment, EditorState } from '@codemirror/state';
import { EditorView, keymap, lineNumbers, highlightActiveLine } from '@codemirror/view';
import { defaultKeymap, history, historyKeymap, undo, redo } from '@codemirror/commands';
import { markdownKeymap } from '@codemirror/lang-markdown';
import { documentLanguage } from './document-language';
import { syntaxHighlighting } from '@codemirror/language';
import { classHighlighter } from '@lezer/highlight';
import { invoke, isTauri } from '@tauri-apps/api/core';
import { open, save, ask } from '@tauri-apps/plugin-dialog';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { fromSource, normalize, savedSource, sourceExtensions, sourceField } from './source';
import { markdownReturn } from './commands';
import { canUseFiles } from './file-guard';
import { livePreview } from './preview';
import { endTableEdit, tableComposing, tableSaveCommand, tableFindCommand } from './table';
import { find, guardedSearchKeymap, outline, refreshOutline, searchSupport } from './navigation';
import { format, Format } from './formatting';
import { insertTable } from './table-insert';
import { codeBlock } from './code-block-command';
import { linkControls } from './link-controls';
import { linkVersion } from './links';
import { themeControls } from './theme';
import { RecoveryCapture, RecoveryListing, RecoveryQueue, recoveryPanel } from './recovery';
import { FileWatcher, FileStatus, fileWarning } from './file-watch';
import { imageDocument, imageBasePath, imagePath, setImagePath } from './images';
import { footnoteField } from './footnotes';
import { insertFootnote, goToFootnote } from './footnote-commands';
import { fileDrops } from './file-drop';
import { fileShortcuts } from './file-shortcuts';
import { DocumentTab, DocumentTabs, documentTabBar, tabDirty, tabName, tabSource } from './document-tabs';
import type { PrintSnapshot } from './print-view';
import { imagePaste } from './image-paste';
import { imageDrops } from './image-drop';
import { copyImageAsset } from './image-assets';
import { clipboardImageControls, droppedImageControls } from './clipboard-assets';
import { toolsPanel } from './tools-panel';
import { fileSidebar } from './file-sidebar';
import { wordCount } from './word-count';
import './style.css';

document.querySelector('#app')!.innerHTML = `<header><strong>MarkBend</strong><button id="new">New</button><button id="open">Open</button><button id="save">Save</button><button id="save-as">Save As</button><button id="undo">Undo</button><button id="redo">Redo</button><button id="find">Find</button><button id="outline-toggle" aria-pressed="false">Outline</button><button id="source" aria-pressed="false">Source</button><button id="check">Check Save</button><span id="status" role="status"></span></header><div class="workspace"><aside id="outline" aria-label="Outline" hidden></aside><main id="editor"></main></div>`;
const app = document.querySelector<HTMLElement>('#app')!;
const documentBar = document.createElement('div'); documentBar.className = 'document-bar';
documentBar.setAttribute('role', 'toolbar'); documentBar.setAttribute('aria-label', 'Document');
const title = document.createElement('span'); title.id = 'document-title';
const countLabel = document.createElement('span'); countLabel.id = 'word-count';
const documentCount = wordCount(countLabel);
window.addEventListener('pagehide', () => documentCount.destroy(), { once: true });
const toolsButton = document.createElement('button'); toolsButton.id = 'tools-toggle'; toolsButton.textContent = 'Tools';
const tools = document.createElement('section'); tools.id = 'tools-panel'; tools.setAttribute('aria-label', 'Document tools'); tools.hidden = true;
const header = document.querySelector('header')!; header.before(documentBar, tools); tools.append(header);
documentBar.append(document.querySelector('#outline-toggle')!, title, countLabel, document.querySelector('#source')!, toolsButton);
const statusBar = document.createElement('footer'); statusBar.className = 'document-status';
statusBar.append(document.querySelector('#status')!); app.append(statusBar);
const outlinePane = document.querySelector<HTMLElement>('#outline')!;
const filesPane = document.createElement('aside'); filesPane.id = 'files'; filesPane.hidden = true; filesPane.setAttribute('aria-label', 'Files');
outlinePane.before(filesPane);
const filesButton = document.createElement('button'); filesButton.id = 'files-toggle'; filesButton.textContent = 'Files'; filesButton.setAttribute('aria-pressed', 'false');
documentBar.prepend(filesButton); documentBar.classList.add('with-files');
themeControls(document.querySelector('header')!);
const formatBar = document.createElement('div');
formatBar.className = 'format-bar'; formatBar.setAttribute('role', 'toolbar'); formatBar.setAttribute('aria-label', 'Formatting');
formatBar.innerHTML = `<button data-format="bold">Bold</button><button data-format="italic">Italic</button><button data-format="strike">Strikethrough</button><button data-format="code">Code</button><select id="heading" aria-label="Heading level"><option value="">Heading…</option><option value="paragraph">Paragraph</option>${Array.from({ length: 6 }, (_, index) => `<option value="h${index + 1}">Heading ${index + 1}</option>`).join('')}</select>`;
document.querySelector('header')!.after(formatBar);
const linkButton = document.createElement('button'); linkButton.textContent = 'Link'; linkButton.id = 'link';
formatBar.append(linkButton);
const status = document.querySelector<HTMLElement>('#status')!;
export let tabs: DocumentTabs;
let busy = isTauri(), terminating = false, lockActive = false;
let pageActive = true;
window.addEventListener('pagehide', () => { pageActive = false; }, { once: true });
const active = () => tabs.active;
const pastedImages = clipboardImageControls(document.querySelector('header')!, {
  native: isTauri(), available: () => !active().path ? 'Save the document before copying pasted images.' :
    active().uncertain ? 'Check the last Save before copying pasted images.' : null,
});
const droppedImages = droppedImageControls(document.querySelector('header')!, {
  native: isTauri(), available: () => !active().path ? 'Save the document before copying dropped images.' :
    active().uncertain ? 'Check the last Save before copying dropped images.' : null,
});
const formComposition = new Set<EventTarget>();
const compositionStart = (event: CompositionEvent) => { if (event.target) formComposition.add(event.target); };
const compositionEnd = (event: CompositionEvent) => { if (event.target) formComposition.delete(event.target); };
document.addEventListener('compositionstart', compositionStart, true);
document.addEventListener('compositionend', compositionEnd, true);
window.addEventListener('pagehide', () => {
  document.removeEventListener('compositionstart', compositionStart, true);
  document.removeEventListener('compositionend', compositionEnd, true); formComposition.clear();
}, { once: true });
const composing = () => view.compositionStarted || tableComposing(view) || [...formComposition].some(target => target instanceof Node && target.isConnected);
let initialization: Promise<void> = Promise.resolve();
let recoveryError: (reason: unknown) => void = reason => { status.textContent = String(reason); };
let fileVersion = 0, watcher: FileWatcher | undefined, showFileWarning: ((status?: FileStatus) => void) | undefined;
function fileTransition() { fileVersion++; watcher?.invalidate(); showFileWarning?.(); view.dispatch({ effects: setImagePath.of(active().path) }); }
const recoveryCapture = (tab: DocumentTab = active()): RecoveryCapture => ({ source: tab === active() ? text() : tabSource(tab), dirty: tabDirty(tab), label: Array.from(tabName(tab)).slice(0, 256).join('') });
function checkpoint(tab: DocumentTab = active()) {
  if (!isTauri()) return;
  if (tab === active()) tab.state = view.state;
  tab.recovery?.update(recoveryCapture(tab));
}
async function flushRecovery(tab: DocumentTab = active()) {
  if (!isTauri()) return;
  await initialization;
  if (!tab.recovery) throw new Error('Recovery is unavailable. Keep this window open.');
  await tab.recovery.flush();
}
const inputLock = new Compartment();
const display = new Compartment();
const text = () => savedSource(view.state.field(sourceField));
const dirty = () => text() !== active().baseline;
let sidebar: ReturnType<typeof fileSidebar> | undefined;
const report = () => { active().state = view.state; status.textContent = `${tabName(active())}${dirty() ? ' • Unsaved' : ''}${active().uncertain ? ' • Check Save' : ''}`;
  documentCount.update(view.state.doc);
  title.textContent = `${tabName(active())}${dirty() ? ' •' : ''}`; title.title = active().path || 'Untitled';
  renderTabs(); sidebar?.select(active().path); };
function applyFormat(kind: Format) { const reason = format(view, kind); if (reason) status.textContent = reason; return true; }
function footnoteCommand(command: typeof insertFootnote) { const reason = command(view); if (reason) status.textContent = reason; return true; }
const formattingKeys = [
  { key: 'Mod-b', run: () => applyFormat('bold') }, { key: 'Mod-i', run: () => applyFormat('italic') },
  { key: 'Mod-Shift-c', run: () => applyFormat('code') },
  ...Array.from({ length: 6 }, (_, index) => ({ key: `Mod-Alt-${index + 1}`, run: () => applyFormat(`h${index + 1}` as Format) })),
];
const state = (source: string, tab?: Pick<DocumentTab, 'id' | 'path' | 'sourceMode'>): EditorState => EditorState.create({ doc: normalize(fromSource(source).raw), extensions: [
  sourceExtensions(fromSource(source)), history(), linkVersion, footnoteField, imageBasePath.of(tab?.path || ''), imageDocument.of(tab?.id ?? 0), imagePath, highlightActiveLine(), inputLock.of([]),
  documentLanguage(), syntaxHighlighting(classHighlighter), EditorView.lineWrapping,
  imagePaste(message => { status.textContent = message; }, () => busy ? 'Wait for the file command, then paste the image.' : composing() ? 'Finish text input, then paste the image.' : null, pastedImages.capture),
  display.of(tab?.sourceMode ? [lineNumbers()] : livePreview),
  tableSaveCommand.of(() => { void operation(saveFile); }),
  tableFindCommand.of(() => { find(view); }), searchSupport(() => view), outline(outlinePane),
  keymap.of([...guardedSearchKeymap, ...formattingKeys, { key: 'Mod-k', run: () => openLinkControls() }, { key: 'Mod-Shift-i', run: () => openImageControls() }, { key: 'Enter', run: markdownReturn }, { key: 'Mod-s', run: () => { void operation(saveFile); return true; } }, ...markdownKeymap.filter(binding => binding.key !== 'Enter'), ...defaultKeymap, ...historyKeymap]),
  EditorView.updateListener.of(update => { if (update.docChanged) { report(); checkpoint(); } }),
] });
export const view: EditorView = new EditorView({ state: state(''), parent: document.querySelector('#editor')! });
tabs = new DocumentTabs({ id: 0, state: view.state, path: '', baseline: '', uncertain: false, sourceMode: false }, inputLock);
const tabContainer = document.createElement('div'); document.querySelector('.workspace')!.before(tabContainer);
const tabBar = documentTabBar(tabContainer, id => { switchTab(id); }, id => { void operation(() => closeTab(id), true); });
function renderTabs() { tabBar.render(tabs); tabContainer.hidden = tabs.all.length < 2; }
const disposeTools = toolsPanel(toolsButton, tools, () => {
  if (!composing()) return true;
  status.textContent = 'Finish text input, then change Tools.'; return false;
}, () => view.requestMeasure());
window.addEventListener('pagehide', disposeTools, { once: true });
const closeDocument = document.createElement('button'); closeDocument.textContent = 'Close document'; closeDocument.id = 'close-document';
closeDocument.addEventListener('click', () => { void operation(() => closeTab(active().id), true); }); header.append(closeDocument);
window.addEventListener('pagehide', () => tabBar.destroy(), { once: true });
const printButton = document.createElement('button'); printButton.id = 'print'; printButton.textContent = 'Print / PDF';
document.querySelector('header')!.append(printButton);
printButton.addEventListener('click', () => {
  if (document.querySelector('.print-dialog')) return;
  void operation(async () => {
    const tab = active();
    const captured: PrintSnapshot = { state: view.state, id: tab.id, path: tab.path, title: tabName(tab) };
    status.textContent = 'Loading print tools…';
    let tools: typeof import('./print-view');
    try { tools = await import('./print-view'); }
    catch (reason) { throw new Error(`Cannot load print tools: ${String(reason)}`); }
    if (!pageActive || terminating) return;
    if (composing()) { status.textContent = 'Finish text input, then repeat Print / PDF.'; return; }
    report();
    await tools.showPrintView(captured);
  });
});
report(); view.focus();
const openLinkControls = linkControls(view, tools, message => { status.textContent = message; });
const codeBlockButton = document.createElement('button'); codeBlockButton.textContent = 'Code Block'; codeBlockButton.id = 'code-block'; formatBar.append(codeBlockButton);
codeBlockButton.addEventListener('mousedown', event => event.preventDefault());
codeBlockButton.addEventListener('click', () => { const reason = codeBlock(view); if (reason) status.textContent = reason; });
const tableButton = document.createElement('button'); tableButton.textContent = 'Table'; tableButton.id = 'insert-table'; formatBar.append(tableButton);
tableButton.addEventListener('mousedown', event => event.preventDefault());
tableButton.addEventListener('click', () => { const reason = insertTable(view); if (reason) status.textContent = reason; });
for (const [name, command] of [['Footnote', insertFootnote], ['Go to Footnote', goToFootnote]] as const) {
  const button = document.createElement('button'); button.textContent = name; formatBar.append(button);
  button.addEventListener('mousedown', event => event.preventDefault());
  button.addEventListener('click', () => footnoteCommand(command));
}
const imageButton = document.createElement('button'); imageButton.textContent = 'Image'; imageButton.id = 'image'; formatBar.append(imageButton);
const openImageControls = linkControls(view, tools, message => { status.textContent = message; }, 'image', isTauri() ? async () => {
  const selected = await open({ multiple: false, filters: [{ name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'] }] });
  return typeof selected === 'string' ? selected : null;
} : undefined, isTauri() ? {
  available: () => !!active().path && !active().uncertain,
  copy: (path, current) => copyImageAsset(view, path, current, () => busy || composing()),
} : undefined);
imageButton.addEventListener('mousedown', event => event.preventDefault());
imageButton.addEventListener('click', openImageControls);
linkButton.addEventListener('mousedown', event => event.preventDefault());
linkButton.addEventListener('click', openLinkControls);
formatBar.querySelectorAll<HTMLButtonElement>('[data-format]').forEach(button => {
  button.addEventListener('mousedown', event => event.preventDefault());
  button.addEventListener('click', () => applyFormat(button.dataset.format as Format));
});
formatBar.querySelector<HTMLSelectElement>('#heading')!.addEventListener('change', event => {
  const select = event.target as HTMLSelectElement;
  if (select.value) applyFormat(select.value as Format); select.value = '';
});
async function operation(action: () => Promise<void>, lock = false) {
  if (!pageActive) return;
  const inputComposing = composing();
  if (!canUseFiles(busy, inputComposing)) {
    if (inputComposing) status.textContent = 'Finish text input, then repeat the file command.';
    return;
  }
  busy = true;
  lockActive = lock; if (lock) applyLock();
  try { await action(); } catch (error) { if (pageActive) status.textContent = typeof error === 'object' && error && 'message' in error ? String(error.message) : String(error); }
  finally { busy = terminating; if (pageActive && !terminating) {
    const unlock = lockActive; lockActive = false; if (unlock) applyLock();
    if (!composing() && !document.querySelector('.print-dialog')) view.focus();
  } }
}
function applyLock() {
  view.dispatch({ effects: inputLock.reconfigure(lockActive ? [EditorState.readOnly.of(true), EditorView.editable.of(false)] : []) });
  document.querySelectorAll<HTMLElement>('.link-controls').forEach(form => { form.inert = lockActive; });
}
function switchTab(id: number, internal = false) {
  if (!tabs.activate(view, id, () => (!busy || internal) && !composing(), () => {
    document.querySelectorAll<HTMLFormElement>('.link-controls').forEach(form => form.querySelector<HTMLButtonElement>('[data-cancel]')!.click());
  })) return false;
  fileTransition();
  document.querySelector('#source')!.setAttribute('aria-pressed', String(active().sourceMode));
  document.querySelector('#editor')!.classList.toggle('source-mode', active().sourceMode);
  document.querySelector('#editor')!.setAttribute('role', 'tabpanel');
  document.querySelector('#editor')!.setAttribute('aria-labelledby', `document-tab-${id}`);
  applyLock(); report(); view.focus(); return true;
}
async function discard(tab: DocumentTab = active()) {
  if (tab.uncertain) throw new Error('Check the last save before you close or reload this file.');
  if (tab === active()) tab.state = view.state;
  return !tabDirty(tab) || await ask(`Discard the unsaved changes in ${tabName(tab)}?`, { title: 'MarkBend', kind: 'warning' });
}
async function saveFile(as = false) {
  const tab = active();
  if (tab.uncertain) throw new Error('Check the last save before you save again.');
  if (!isTauri()) throw new Error('Open the desktop app to use file commands.');
  const destination = !as && tab.path ? tab.path : await save({ defaultPath: tab.path || 'Untitled.md', filters: [{ name: 'Markdown', extensions: ['md', 'markdown'] }] });
  if (!destination) return;
  const captured = text();
  try { await invoke('save_document', { document: tab.id, path: destination, source: captured }); }
  catch (error) {
    if (typeof error === 'object' && error && 'uncertain' in error && error.uncertain) {
      tab.uncertain = true; tab.path = destination; tab.baseline = captured;
      fileTransition(); showFileWarning?.({ kind: 'uncertain', generation: -1 });
      checkpoint();
      throw new Error(`Save completion is uncertain. Use Check Save. ${'message' in error ? error.message : ''}`);
    }
    throw error;
  }
  tab.path = destination; tab.baseline = captured; fileTransition(); report(); checkpoint(tab); await flushRecovery(tab);
}
let browserID = 0;
function attachRecovery(tab: DocumentTab, listing: Pick<RecoveryListing, 'session' | 'revision'>) {
  const id = tab.id, session = listing.session; tab.recoverySession = session;
  tab.recovery = new RecoveryQueue(listing.revision,
    capture => invoke('recovery_checkpoint', { document: id, session, ...capture }), recoveryError);
}
async function createTab(source = '', file?: string): Promise<DocumentTab> {
  const id = isTauri() ? await invoke<number>('create_document') : ++browserID;
  const tab: DocumentTab = { id, path: '', baseline: '', uncertain: false, sourceMode: false, state: state('', { id, path: '', sourceMode: false }) };
  try {
    if (isTauri()) attachRecovery(tab, await invoke<RecoveryListing>('recovery_document', { document: id }));
    if (file) {
      const loaded = await invoke<{ source: string; path: string }>('open_document', { document: id, path: file });
      source = loaded.source; tab.path = loaded.path; tab.baseline = loaded.source;
    }
    tab.state = state(source, tab);
    if (isTauri()) { checkpoint(tab); await tab.recovery!.flush(); }
    return tab;
  } catch (error) {
    try {
      if (isTauri()) {
        if (!tab.recovery) attachRecovery(tab, await invoke<RecoveryListing>('recovery_document', { document: id }));
        const revision = await tab.recovery!.clear();
        await invoke('retire_document', { document: id, session: tab.recoverySession, revision });
      }
    } catch (cleanup) {
      // A host entry that could not retire must remain reachable for retry.
      tabs.add(tab); renderTabs(); recoveryError(cleanup);
    }
    throw error;
  }
}
async function addDocument(source = '', file?: string) {
  checkpoint(); await flushRecovery();
  const tab = await createTab(source, file); tabs.add(tab); switchTab(tab.id, true);
}
async function closeTab(id: number) {
  const tab = tabs.get(id); if (!tab || !await discard(tab)) return;
  checkpoint(tab); await flushRecovery(tab);
  let replacement: DocumentTab | undefined;
  if (tabs.all.length === 1) { replacement = await createTab(); tabs.add(replacement); renderTabs(); }
  const previous = active().id;
  // Adopt a valid replacement while the old host document is still live. A
  // rejected activation must not leave an active view for a retired document.
  if (active() === tab && !switchTab((replacement || tabs.all.find(other => other !== tab)!).id, true)) {
    throw new Error('Finish text input, then close this tab again.');
  }
  try {
    if (isTauri()) {
      if (!tab.recovery) throw new Error('Recovery is unavailable. Keep this tab open.');
      const revision = await tab.recovery.clear();
      await invoke('retire_document', { document: tab.id, session: tab.recoverySession, revision });
    }
  } catch (error) {
    checkpoint(tab); await flushRecovery(tab).catch(recoveryError); switchTab(previous, true); throw error;
  }
  tabs.remove(id); report();
}
document.querySelector('#new')!.addEventListener('click', () => void operation(() => addDocument(), true));
document.querySelector('#open')!.addEventListener('click', () => void operation(async () => {
  if (!isTauri()) throw new Error('Open the desktop app to use file commands.');
  const selected = await open({ multiple: false, filters: [{ name: 'Markdown', extensions: ['md', 'markdown', 'txt'] }] });
  if (typeof selected !== 'string') return;
  await loadFile(selected);
}, true));
async function loadFile(selected: string) {
  await addDocument('', selected);
}
sidebar = fileSidebar(filesPane, {
  read: path => invoke('list_directory', { path }),
  allowed: () => {
    if (!pageActive || busy) return false;
    if (composing()) { status.textContent = 'Finish text input, then use Files.'; return false; }
    return true;
  },
  choose: async () => {
    let selected: string | null = null;
    await operation(async () => {
      if (!isTauri()) throw new Error('Open the desktop app to choose a folder.');
      const path = await open({ directory: true, multiple: false });
      if (typeof path === 'string') selected = path;
    }, true);
    return selected;
  },
  open: path => { void operation(async () => {
    const existing = tabs.all.find(tab => tab.path === path);
    if (existing) { switchTab(existing.id, true); return; }
    await loadFile(path);
  }, true); },
});
sidebar.select(active().path);
window.addEventListener('pagehide', () => sidebar?.dispose(), { once: true });
filesButton.addEventListener('click', () => {
  if (busy || composing()) { status.textContent = 'Finish the file command or text input, then use Files.'; return; }
  filesPane.hidden = !filesPane.hidden; filesButton.setAttribute('aria-pressed', String(!filesPane.hidden));
  if (!filesPane.hidden) { outlinePane.hidden = true; document.querySelector('#outline-toggle')!.setAttribute('aria-pressed', 'false'); }
  view.dispatch({ effects: refreshOutline.of(null) }); view.requestMeasure();
});
if (isTauri()) {
  const hint = document.createElement('div'); hint.className = 'file-drop-hint'; hint.hidden = true;
  hint.setAttribute('role', 'status'); hint.textContent = 'Drop to open this Markdown file.';
  document.querySelector('.workspace')!.append(hint);
  const images = imageDrops(view, { scale: () => getCurrentWindow().scaleFactor(),
    policy: droppedImages.capture,
    report: message => { status.textContent = message; },
    blocked: () => busy ? 'Wait for the file command, then drop the image.' : composing() ? 'Finish text input, then drop the image.' : null });
  const dispose = fileDrops(handler => getCurrentWindow().onDragDropEvent(handler),
    selected => { void operation(() => loadFile(selected), true); },
    message => { status.textContent = message; }, (visible, image) => {
      hint.hidden = !visible; hint.textContent = image ? 'Drop this image into document text.' : 'Drop to open this Markdown file.';
    }, (path, position) => { void images.drop(path, position); });
  window.addEventListener('pagehide', () => { dispose(); images.dispose(); }, { once: true });
}
document.querySelector('#save')!.addEventListener('click', () => void operation(saveFile));
document.querySelector('#save-as')!.addEventListener('click', () => void operation(() => saveFile(true)));
if (isTauri()) {
  const dispose = fileShortcuts(document, /Mac|iPhone|iPad|iPod/.test(navigator.platform),
    () => view.compositionStarted || tableComposing(view));
  window.addEventListener('pagehide', dispose, { once: true });
}
document.querySelector('#undo')!.addEventListener('click', () => { if (!view.compositionStarted && !tableComposing(view)) { undo(view); view.focus(); } });
document.querySelector('#redo')!.addEventListener('click', () => { if (!view.compositionStarted && !tableComposing(view)) { redo(view); view.focus(); } });
document.querySelector('#find')!.addEventListener('click', () => {
  if (!find(view)) status.textContent = 'Finish text input, then open Find.';
});
document.querySelector('#outline-toggle')!.addEventListener('click', () => {
  if (busy || composing()) return;
  outlinePane.hidden = !outlinePane.hidden;
  if (!outlinePane.hidden) { filesPane.hidden = true; filesButton.setAttribute('aria-pressed', 'false'); }
  document.querySelector('#outline-toggle')!.setAttribute('aria-pressed', String(!outlinePane.hidden));
  view.dispatch({ effects: refreshOutline.of(null) });
  view.requestMeasure();
});
document.querySelector('#source')!.addEventListener('click', () => {
  if (composing()) { status.textContent = 'Finish text input, then change the display.'; return; }
  active().sourceMode = !active().sourceMode;
  document.querySelector('#source')!.setAttribute('aria-pressed', String(active().sourceMode));
  document.querySelector('#editor')!.classList.toggle('source-mode', active().sourceMode);
  view.dispatch({ effects: display.reconfigure(active().sourceMode ? [lineNumbers()] : livePreview) }); active().state = view.state; view.focus();
});
document.querySelector('#check')!.addEventListener('click', () => void operation(async () => { const tab = active(); await invoke('check_save', { document: tab.id }); tab.uncertain = false; fileTransition(); report(); checkpoint(tab); await flushRecovery(tab); }));
async function reloadFile() {
  const tab = active(); if (!tab.path) return;
  if (!await discard()) return;
  checkpoint(); await flushRecovery();
  const loaded = await invoke<{ source: string; path: string }>('open_document', { document: tab.id, path: tab.path });
  tab.path = loaded.path; tab.baseline = loaded.source; fileTransition(); view.setState(state(loaded.source, tab)); applyLock();
  report(); checkpoint(); await flushRecovery();
}
if (isTauri()) {
  showFileWarning = fileWarning(tools, () => void operation(reloadFile, true),
    () => void operation(() => saveFile(true)), () => void watcher?.check());
  watcher = new FileWatcher(() => active().path ? { path: active().path, version: fileVersion } : undefined,
    () => !busy && !composing(),
    () => invoke<FileStatus>('file_status', { document: active().id }), result => showFileWarning!(result));
  const checkFile = document.createElement('button'); checkFile.textContent = 'Check File'; checkFile.id = 'check-file';
  checkFile.addEventListener('click', () => void watcher?.check()); document.querySelector('header')!.append(checkFile);
  const timer = setInterval(() => { if (document.visibilityState === 'visible') void watcher?.check(); }, 2000);
  window.addEventListener('focus', () => void watcher?.check());
  window.addEventListener('pagehide', () => { clearInterval(timer); watcher?.dispose(); }, { once: true });
}
if (isTauri()) {
  const panel = recoveryPanel(tools,
    async () => { await initialization; return await invoke<RecoveryListing>('recovery_list', { document: active().id }); },
    async id => {
      // operation reports errors to the app and keeps current source on failures.
      await operation(async () => {
        checkpoint(); await flushRecovery();
        const tab = active(); const copy = await invoke<{ source: string; label: string }>('recovery_copy', { document: tab.id, id });
        await addDocument(copy.source);
      }, true);
    }, async () => {
      if (!started) { await startRecovery(); return; }
      for (const tab of tabs.all) {
        if (!tab.recovery) attachRecovery(tab, await invoke<RecoveryListing>('recovery_document', { document: tab.id }));
        checkpoint(tab); await flushRecovery(tab);
      }
    });
  recoveryError = panel.error;
  const recoveryButton = document.createElement('button'); recoveryButton.textContent = 'Recovery';
  document.querySelector('header')!.append(recoveryButton);
  recoveryButton.addEventListener('click', () => void panel.show());
  type Startup = { documents: { id: number; path: string; baseline: string; uncertain: boolean }[];
    sessions: { document: number; session: string; revision: number }[]; recovery: RecoveryListing };
  let started = false, starting = false;
  function startRecovery(): Promise<void> {
    if (starting) return initialization;
    if (busy && started) return initialization;
    starting = true;
    busy = true; lockActive = true; applyLock();
    const previous = active(); previous.state = view.state;
    initialization = invoke<Startup>('document_start').then(startup => {
      if (!startup.documents.length) throw new Error('No document returned by the host. Retry recovery.');
      const documents = startup.documents.map(info => {
        // Programmatic early edits in a fresh empty document are kept. Native
        // input is locked until startup completes.
        const source = info.id === previous.id && !info.path && !info.baseline ? tabSource(previous) : info.baseline;
        const tab: DocumentTab = { ...info, sourceMode: false, state: state(source, { ...info, sourceMode: false }) };
        const token = startup.sessions.find(token => token.document === tab.id);
        if (!token) throw new Error('Recovery session is missing. Retry recovery.');
        attachRecovery(tab, token); return tab;
      });
      tabs = new DocumentTabs(documents[0], inputLock);
      for (const tab of documents.slice(1)) tabs.add(tab);
      view.setState(active().state); busy = false; lockActive = false; applyLock();
      started = true; fileTransition(); report(); checkpoint();
      document.querySelector('#editor')!.setAttribute('role', 'tabpanel');
      document.querySelector('#editor')!.setAttribute('aria-labelledby', `document-tab-${active().id}`);
    }).catch(reason => { panel.error(reason); throw reason; }).finally(() => { starting = false; });
    return initialization;
  }
  void startRecovery().then(() => panel.show(true)).catch(() => {});
}
if (isTauri()) void getCurrentWindow().onCloseRequested(async event => {
  event.preventDefault(); if (busy) return;
  await operation(async () => {
    for (const tab of tabs.all) if (!await discard(tab)) return;
    for (const tab of tabs.all) { checkpoint(tab); await flushRecovery(tab); }
    try {
      for (const tab of tabs.all) await tab.recovery!.clear();
      await getCurrentWindow().destroy();
    } catch (error) {
      // Window Close clears are not atomic. Rebuild every retained dirty copy
      // when a later clear or destruction fails; keep the window open.
      for (const tab of tabs.all) checkpoint(tab);
      const results = await Promise.allSettled(tabs.all.map(tab => flushRecovery(tab)));
      for (const result of results) if (result.status === 'rejected') recoveryError(result.reason);
      throw error;
    }
  }, true);
});
if (isTauri()) {
  let activeQuit: number | undefined;
  async function quit(request: number) {
    if (!Number.isSafeInteger(request) || request <= 0 || activeQuit === request) return;
    activeQuit = request;
    let approved = false;
    if (busy || composing()) {
      status.textContent = 'Finish the current command or text input, then repeat Quit.';
    } else await operation(async () => {
      for (const tab of tabs.all) if (!await discard(tab)) return;
      // Quit keeps the confirmed recovery copy. Close has a separate clear policy.
      for (const tab of tabs.all) { checkpoint(tab); await flushRecovery(tab); }
      await invoke('resolve_quit', { request, allow: true });
      approved = true; terminating = true;
    }, true);
    if (!approved) {
      try { await invoke('resolve_quit', { request, allow: false }); }
      catch (error) { status.textContent = String(error); }
    }
    activeQuit = undefined;
  }
  void (async () => {
    let ready = false, queued: number | undefined;
    await getCurrentWindow().listen<number>('markbend-quit-request', event => {
      if (ready) void quit(event.payload); else queued = event.payload;
    });
    const pending = await invoke<number | null>('quit_ready');
    ready = true;
    if (pending != null) void quit(pending); else if (queued != null) void quit(queued);
  })().catch(error => { status.textContent = `Quit protection is unavailable. Keep this window open. ${String(error)}`; });
}
