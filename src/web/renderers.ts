import DOMPurify from 'dompurify';
import MarkdownIt from 'markdown-it';
import { ImageInfo, imageInfo } from './images';

const markdown = new MarkdownIt({ html: true, linkify: false });
export const renderedMarkdown = (source: string) => DOMPurify.sanitize(markdown.render(source));
const tableMarkdown = new MarkdownIt({ html: false, linkify: false });
interface TableImageEnvironment { references?: object; tableImages?: ImageInfo[]; path?: string; document?: number }
tableMarkdown.renderer.rules.image = (tokens, index, _options, environment: TableImageEnvironment) => {
  const image = imageInfo(tokens[index], environment.path || '', environment.document);
  if (!environment.tableImages) return tableMarkdown.utils.escapeHtml(image.alt);
  const slot = environment.tableImages.length; environment.tableImages.push(image);
  return `<span class="preview-image table-image" data-table-image="${slot}">${tableMarkdown.utils.escapeHtml(image.alt)}</span>`;
};
export const renderedTable = (source: string) => DOMPurify.sanitize(tableMarkdown.render(source), {
  FORBID_TAGS: ['a', 'img'], FORBID_ATTR: ['style', 'id', 'name', 'href', 'src', 'srcset'],
});
export function tableImageEnvironment(source: string): TableImageEnvironment {
  const environment = {}; tableMarkdown.parse(source, environment); return environment;
}
export function tableProjection(source: string, references: TableImageEnvironment, path: string, document?: number) {
  const images: ImageInfo[] = [];
  const html = DOMPurify.sanitize(tableMarkdown.render(source, { ...references, tableImages: images, path, document }), {
    FORBID_TAGS: ['a', 'img'], FORBID_ATTR: ['style', 'id', 'name', 'href', 'src', 'srcset'],
  });
  return { html, images };
}
export function htmlFrame(source: string): string {
  const html = DOMPurify.sanitize(source, { ADD_TAGS: ['style'], FORCE_BODY: true,
    FORBID_TAGS: ['script', 'iframe', 'object', 'embed', 'base', 'link', 'meta'],
    FORBID_ATTR: ['href', 'srcset', 'action', 'formaction'] });
  return `<!doctype html><html><head><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:; form-action 'none'; base-uri 'none'"><style>body{margin:12px;color:#24272c;background:white;font:16px system-ui}img{max-width:100%}</style></head><body>${html}</body></html>`;
}

let diagramId = 0;
let mermaidModule: Promise<typeof import('mermaid')> | undefined;
export async function renderDiagram(source: string): Promise<string> {
  mermaidModule ??= import('mermaid').then(module => {
    module.default.initialize({ startOnLoad: false, securityLevel: 'strict', theme: 'default', htmlLabels: false,
      suppressErrorRendering: true, flowchart: { htmlLabels: false } });
    return module;
  });
  const mermaid = (await mermaidModule).default;
  const { svg } = await mermaid.render(`markbend-diagram-${++diagramId}`, source);
  return DOMPurify.sanitize(svg, { USE_PROFILES: { svg: true, svgFilters: true },
    FORBID_TAGS: ['a', 'foreignObject'], FORBID_ATTR: ['href', 'xlink:href'] });
}

// A removed widget must never publish a result into a newer edit surface.
export function mountResult(dom: HTMLElement, result: Promise<string>, measure: () => void) {
  let alive = true;
  result.then(html => {
    if (!alive || !dom.isConnected) return;
    dom.innerHTML = html; dom.dataset.ready = 'true'; measure();
  }, error => {
    if (!alive || !dom.isConnected) return;
    dom.classList.add('preview-error'); dom.textContent = `Cannot render: ${String(error)}. Select to edit the source.`;
    dom.dataset.ready = 'error'; measure();
  });
  return () => { alive = false; };
}
