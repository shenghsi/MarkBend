import DOMPurify from 'dompurify';
import { toHtml } from 'hast-util-to-html';
import type { Text } from '@codemirror/state';
import type { blockHTML } from './inline-html';
import { documentImageEnvironment, htmlFrame } from './renderers';

export interface BlockHTMLPreview { source: string; doc: Text; bodyFrom: number; from: number; to: number }
export type BlockHTMLLoader = () => Promise<typeof blockHTML>;
const load: BlockHTMLLoader = () => import('./inline-html').then(module => module.blockHTML);

export function mountBlockHTML(dom: HTMLElement, preview: BlockHTMLPreview,
  measure: () => void, loader: BlockHTMLLoader = load) {
  let alive = true;
  const current = () => alive && dom.isConnected;
  dom.textContent = preview.source; dom.dataset.ready = 'loading';
  const caption = (isolated = false) => {
    const label = document.createElement('span'); label.className = 'preview-caption';
    label.textContent = `HTML · ${isolated ? 'isolated preview · ' : ''}select to edit`; return label;
  };
  const fallback = (reason: unknown) => {
    if (!current()) return;
    const frame = document.createElement('iframe'); frame.title = 'HTML preview';
    frame.setAttribute('sandbox', ''); frame.tabIndex = -1; frame.srcdoc = htmlFrame(preview.source);
    dom.replaceChildren(frame, caption(true)); dom.dataset.ready = 'isolated';
    dom.title = `Isolated HTML preview: ${String(reason)}`; measure();
  };
  void (async () => {
    await Promise.resolve(); if (!current()) return;
    const format = await loader(); if (!current()) return;
    // Both parsers must agree on the original UTF-16 source bounds. Only the
    // package value removes container prefixes; reveal retains original bounds.
    const from = preview.from - preview.bodyFrom, to = preview.to - preview.bodyFrom;
    const value = documentImageEnvironment(preview.doc, preview.bodyFrom).htmlBlocks?.get(`${from}:${to}`);
    if (value === undefined || preview.source.length !== to - from ||
      preview.doc.sliceString(preview.from, preview.to) !== preview.source) {
      fallback('Unsupported Markdown fragment'); return;
    }
    const result = format(value);
    if (!result) { fallback('Unsupported block HTML'); return; }
    const body = document.createElement('div'); body.className = 'preview-block-html-body';
    body.innerHTML = DOMPurify.sanitize(toHtml(result), {
      FORBID_TAGS: ['script', 'style', 'iframe', 'object', 'embed', 'form', 'button', 'img', 'svg', 'math'],
      FORBID_ATTR: ['style', 'id', 'name', 'href', 'src', 'srcset', 'action', 'formaction'],
    });
    dom.replaceChildren(body, caption()); dom.classList.add('preview-block-html');
    dom.dataset.ready = 'true'; measure();
  })().catch(fallback);
  return () => { alive = false; };
}
