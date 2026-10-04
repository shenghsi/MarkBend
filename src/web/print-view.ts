import { EditorState } from '@codemirror/state';
import { ensureSyntaxTree, LanguageDescription } from '@codemirror/language';
import { languages } from '@codemirror/language-data';
import { classHighlighter, highlightTree } from '@lezer/highlight';
import { fromMarkdown } from 'mdast-util-from-markdown';
import { gfm } from 'micromark-extension-gfm';
import { gfmFromMarkdown } from 'mdast-util-gfm';
import { math } from 'micromark-extension-math';
import { mathFromMarkdown } from 'mdast-util-math';
import { toHast } from 'mdast-util-to-hast';
import { toHtml } from 'hast-util-to-html';
import DOMPurify from 'dompurify';
import type { Root, RootContent } from 'mdast';
import type { Element } from 'hast';
import { htmlFrame, renderDiagram } from './renderers';
import { mountImage } from './images';
import './print.css';
import { exportPNG } from './png-export';
import { isTauri } from '@tauri-apps/api/core';

export interface PrintSnapshot {
  state: EditorState; id: number; path: string; title: string;
}
interface Renderers {
  formula: (source: string, display: boolean) => Promise<string>;
  diagram: (source: string) => Promise<string>;
}
const defaults: Renderers = {
  formula: (source, display) => import('./math-renderer').then(module => module.renderMath(source, display)),
  diagram: renderDiagram,
};

// This complete document projection never reads the virtualized editor DOM.
export function printView(snapshot: PrintSnapshot, renderers: Renderers = defaults) {
  const captured = Object.freeze({ ...snapshot });
  const source = captured.state.doc.toString();
  const tree = ensureSyntaxTree(captured.state, captured.state.doc.length, 1000);
  if (!tree) throw new Error('Cannot finish the document parse. Close this view and retry.');
  const metadata = tree.topNode.getChild('Frontmatter');
  const body = source.slice(metadata?.to || 0);
  const ast = fromMarkdown(body, { extensions: [gfm(), math()], mdastExtensions: [gfmFromMarkdown(), mathFromMarkdown()] });
  // Match definition preview: HTML is literal, images are alt text, and nested
  // footnote calls are literal. Authored links have no actions in print output.
  function notes(node: Root | RootContent, inNote = false) {
    if (inNote && ['html', 'image', 'imageReference', 'footnoteReference'].includes(node.type)) {
      const value = node.type === 'html' ? node.value : node.type === 'footnoteReference' ? `[^${node.label || node.identifier}]`
        : 'alt' in node ? node.alt || '' : '';
      Object.assign(node, { type: 'text', value }); return;
    }
    if ('children' in node) for (const child of node.children) notes(child, inNote || node.type === 'footnoteDefinition');
  }
  notes(ast);
  type Pending = { kind: 'math' | 'diagram' | 'image' | 'html' | 'code'; source: string; display?: boolean; alt?: string; title?: string; language?: string };
  const pending: Pending[] = [];
  const slot = (entry: Pending): Element => {
    const index = pending.push(entry) - 1;
    return { type: 'element', tagName: (entry.kind === 'math' || entry.kind === 'html') && !entry.display || entry.kind === 'image' ? 'span' : 'div',
      properties: { dataPrintSlot: String(index), className: [`print-${entry.kind}`] }, children: [{ type: 'text', value: entry.source }] };
  };
  const hast = toHast(ast, { allowDangerousHtml: false, footnoteLabel: 'Footnotes', handlers: {
    html: (_state, node, parent) => slot({ kind: 'html', source: node.value, display: parent?.type === 'root' || parent?.type === 'blockquote' || parent?.type === 'listItem' }),
    math: (_state, node) => slot({ kind: 'math', source: node.value, display: true }),
    inlineMath: (_state, node) => slot({ kind: 'math', source: node.value, display: false }),
    image: (_state, node) => slot({ kind: 'image', source: node.url, alt: node.alt || '', title: node.title || '' }),
    imageReference: (state, node) => {
      const definition = state.definitionById.get(node.identifier.toUpperCase());
      return definition ? slot({ kind: 'image', source: definition.url, alt: node.alt || '', title: definition.title || '' })
        : { type: 'text', value: node.alt || '' };
    },
    code: (_state, node) => {
      const language = node.lang;
      return slot({ kind: language === 'mermaid' ? 'diagram' : language === 'math' || language === 'latex' ? 'math' : 'code',
        source: node.value, language: node.lang || '', display: true });
    },
  } });
  const element = document.createElement('article'); element.className = 'print-paper'; element.setAttribute('aria-label', captured.title);
  element.innerHTML = DOMPurify.sanitize(toHtml(hast!), {
    FORBID_TAGS: ['script', 'style', 'iframe', 'object', 'embed', 'form', 'button', 'img', 'link', 'meta'],
    FORBID_ATTR: ['style', 'href', 'src', 'srcset', 'action', 'formaction', 'name'],
  });
  if (metadata) {
    const pre = document.createElement('pre'); pre.className = 'print-metadata'; pre.textContent = source.slice(0, metadata.to); element.prepend(pre);
  }
  let alive = true;
  const warnings: string[] = [], disposers: (() => void)[] = [];
  const jobs: Promise<void>[] = [];
  const fail = (dom: HTMLElement, entry: Pending, reason: unknown) => {
    if (!alive) return;
    const message = `Cannot render ${entry.kind}: ${String(reason)}`;
    warnings.push(message); dom.classList.add('print-error'); dom.textContent = `${message}\n${entry.source}`;
  };
  // Every task has a finite wait. Closing releases timers, object URLs, and
  // pending publication, including jobs that cannot themselves be cancelled.
  function settle(work: Promise<void>, timeout: () => void) {
    jobs.push(new Promise<void>(resolve => {
      let done = false;
      const finish = () => { if (done) return; done = true; clearTimeout(timer); resolve(); };
      const timer = setTimeout(() => { if (!done && alive) timeout(); finish(); }, 15000);
      disposers.push(finish); void work.finally(finish);
    }));
  }
  for (const [index, entry] of pending.entries()) {
    const dom = element.querySelector<HTMLElement>(`[data-print-slot="${index}"]`)!;
    let expired = false;
    let releaseResource = () => {};
    const current = () => alive && !expired;
    if (entry.kind === 'html') {
      if (!entry.display) {
        dom.textContent = entry.source;
        if (!warnings.includes('Inline HTML is printed as source.')) warnings.push('Inline HTML is printed as source.');
        continue;
      }
      const frame = document.createElement('iframe'); frame.title = 'HTML content'; frame.setAttribute('sandbox', '');
      frame.referrerPolicy = 'no-referrer'; frame.srcdoc = htmlFrame(entry.source); dom.replaceChildren(frame);
      warnings.push('HTML uses an isolated frame. Check for clipped content before printing.');
      settle(new Promise(resolve => { frame.addEventListener('load', () => resolve(), { once: true }); }),
        () => { expired = true; fail(dom, entry, 'HTML loading timed out.'); });
    } else if (entry.kind === 'image') {
      let finish: () => void;
      const loaded = new Promise<void>(resolve => { finish = resolve; });
      const disposeImage = mountImage(dom, { destination: entry.source, alt: entry.alt || '', title: entry.title || '', path: captured.path, document: captured.id }, () => {
        if (dom.dataset.ready === 'error') warnings.push(`Cannot load image: ${entry.alt || entry.source}`);
        finish();
      });
      disposers.push(disposeImage);
      settle(loaded, () => { expired = true; disposeImage(); fail(dom, entry, 'Image loading timed out.'); });
    } else {
      const work = (async () => {
        if (entry.kind === 'code') {
          const pre = document.createElement('pre'), code = document.createElement('code'); pre.append(code);
          const language = LanguageDescription.matchLanguageName(languages, entry.language!.split(/\s/)[0], false);
          if (language) {
            const support = await language.load(); if (!current()) return;
            let position = 0;
            highlightTree(support.language.parser.parse(entry.source), classHighlighter, (from, to, classes) => {
              code.append(document.createTextNode(entry.source.slice(position, from)));
              const token = document.createElement('span'); token.className = classes; token.textContent = entry.source.slice(from, to); code.append(token); position = to;
            });
            code.append(document.createTextNode(entry.source.slice(position)));
          } else code.textContent = entry.source;
          if (current()) dom.replaceChildren(pre);
        } else if (entry.kind === 'diagram') {
          const rendered = await renderers.diagram(entry.source); if (!current()) return;
          // Mermaid's layout CSS stays inside an SVG image, outside app CSS.
          const svg = DOMPurify.sanitize(rendered, { USE_PROFILES: { svg: true, svgFilters: true },
            FORBID_TAGS: ['a', 'foreignObject'], FORBID_ATTR: ['href', 'xlink:href'] });
          let url: string | undefined = URL.createObjectURL(new Blob([svg], { type: 'image/svg+xml' }));
          const image = document.createElement('img'); image.alt = 'Mermaid diagram';
          const release = () => { image.removeAttribute('src'); if (url) URL.revokeObjectURL(url); url = undefined; };
          releaseResource = release;
          disposers.push(release); dom.replaceChildren(image);
          await new Promise<void>((resolve, reject) => {
            image.onload = () => resolve(); image.onerror = () => { release(); reject(new Error('Cannot load the diagram image.')); };
            image.src = url!;
          });
        } else {
          const rendered = await renderers.formula(entry.source, !!entry.display);
          if (current()) dom.innerHTML = DOMPurify.sanitize(rendered, { ADD_TAGS: ['mjx-container'],
            FORBID_TAGS: ['script', 'style', 'a', 'img', 'iframe', 'object', 'embed', 'foreignObject'],
            FORBID_ATTR: ['href', 'xlink:href', 'src', 'srcset'] });
        }
      })().catch(reason => { if (current()) fail(dom, entry, reason); });
      settle(work, () => { expired = true; releaseResource(); fail(dom, entry, 'Rendering timed out.'); });
    }
  }
  const ready = Promise.all(jobs).then(() => warnings);
  return { element, ready, snapshot: captured, dispose() { alive = false; for (const dispose of disposers) dispose(); element.remove(); } };
}

export async function showPrintView(snapshot: PrintSnapshot) {
  const projection = printView(snapshot);
  const dialog = document.createElement('dialog'); dialog.className = 'print-dialog'; dialog.setAttribute('aria-label', 'Print document');
  const controls = document.createElement('div'); controls.className = 'print-controls';
  const label = document.createElement('span'); label.textContent = `${snapshot.title} — Preparing document…`; label.setAttribute('role', 'status');
  const print = document.createElement('button'); print.textContent = 'Print…'; print.disabled = true;
  const png = document.createElement('button'); png.textContent = 'Export PNG…'; png.disabled = true; png.id = 'export-png';
  const close = document.createElement('button'); close.textContent = 'Close'; controls.append(label, print, png, close);
  const hint = document.createElement('p'); hint.className = 'print-hint'; hint.textContent = 'Use the system print dialog to select paper or Save as PDF, where available. HTTPS images load from their servers.';
  const errors = document.createElement('ul'); errors.className = 'print-warnings';
  const pngPreview = document.createElement('details'); pngPreview.className = 'png-preview'; pngPreview.hidden = true;
  const previewLabel = document.createElement('summary'); previewLabel.textContent = 'PNG preview'; pngPreview.append(previewLabel);
  dialog.append(controls, hint, errors, pngPreview, projection.element); document.body.append(dialog);
  let closed = false;
  let pngBusy = false, writing = false;
  const exportSignal = new AbortController();
  let pngURL: string | undefined;
  const previousFocus = document.activeElement;
  const cleanup = () => { if (closed) return; closed = true; exportSignal.abort(); if (pngURL) URL.revokeObjectURL(pngURL); projection.dispose(); dialog.remove(); window.removeEventListener('pagehide', cleanup); if (previousFocus instanceof HTMLElement && previousFocus.isConnected) previousFocus.focus(); };
  close.onclick = () => { if (!writing) cleanup(); }; dialog.addEventListener('cancel', event => { event.preventDefault(); if (!writing) cleanup(); });
  window.addEventListener('pagehide', cleanup, { once: true });
  try { dialog.showModal(); } catch (error) { cleanup(); throw error; }
  print.onclick = () => {
    try { window.print(); } catch (reason) { label.textContent = `Cannot open the print dialog: ${String(reason)}`; }
  };
  const pngUnavailable = !!projection.element.querySelector('iframe');
  png.onclick = () => {
    if (pngBusy || closed) return;
    pngBusy = true; png.disabled = true; print.disabled = true; label.textContent = `${snapshot.title} — Preparing PNG…`;
    void exportPNG(projection.element, projection.snapshot.title, exportSignal.signal, () => {
      writing = true; close.disabled = true; label.textContent = `${snapshot.title} — Saving PNG…`;
    }, undefined, bytes => {
      if (pngURL) URL.revokeObjectURL(pngURL);
      pngURL = URL.createObjectURL(new Blob([bytes as BlobPart], { type: 'image/png' }));
      const image = document.createElement('img'); image.alt = 'Exported PNG preview'; image.src = pngURL;
      pngPreview.replaceChildren(previewLabel, image); pngPreview.hidden = false;
    }).then(saved => { if (!closed) label.textContent = saved ? `${snapshot.title} — ${isTauri() ? 'PNG exported.' : 'PNG prepared; download requested.'}` : `${snapshot.title} — Export canceled.`; },
      reason => { if (!closed) label.textContent = `Cannot export PNG: ${String(reason)}`; }).finally(() => {
        writing = false; pngBusy = false; if (!closed) { close.disabled = false; png.disabled = pngUnavailable; print.disabled = false; }
      });
  };
  dialog.addEventListener('keydown', event => {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'p') {
      event.preventDefault(); if (!print.disabled) print.click();
    }
  });
  const warnings = await projection.ready;
  if (closed) return;
  for (const warning of warnings) { const item = document.createElement('li'); item.textContent = warning; errors.append(item); }
  label.textContent = `${snapshot.title}${warnings.length ? ' — Check the warnings before printing.' : ' — Ready to print.'}`;
  print.textContent = warnings.length ? 'Print with warnings…' : 'Print…'; print.disabled = false;
  png.textContent = warnings.length ? 'Export PNG with warnings…' : 'Export PNG…'; png.disabled = pngUnavailable;
  if (pngUnavailable) png.title = 'PNG export is unavailable for documents with block HTML. Use Print.';
}
