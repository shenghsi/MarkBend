import { EditorView, ViewPlugin, ViewUpdate } from '@codemirror/view';
import { ensureSyntaxTree } from '@codemirror/language';
import { imageDocument, imageLimit, imageMime, imagePath } from './images';
import { planLink, linkCaptureCurrent, LinkEdit, openLink } from './links';
import { editGuard } from './edit-guard';
import { rawOffset, savedSource, sourceField } from './source';
import { clipboardImageFiles, imagePasteMessage } from './clipboard';

const sourceLimit = 8 * 1024 * 1024;
const supported = new Set(['image/png', 'image/jpeg', 'image/gif', 'image/webp']);
const size = (text: string) => new TextEncoder().encode(text).length;
function fits(view: EditorView, edit: LinkEdit, bytes: number, type: string) {
  const record = view.state.field(sourceField);
  const from = edit.existing ? edit.destinationFrom : edit.from, to = edit.existing ? edit.destinationTo : edit.to;
  const removed = record.raw.slice(rawOffset(record.raw, from), rawOffset(record.raw, to));
  const inserted = edit.existing ? `<data:${type};base64,>` : `![${edit.label}](<data:${type};base64,>)`;
  return size(savedSource(record)) - size(removed) + size(inserted)
    + Math.ceil(bytes / 3) * 4 <= sourceLimit;
}
function readImage(file: File): Promise<Uint8Array> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(reader.error || new Error('Cannot read the clipboard image.'));
    reader.onabort = () => reject(new Error('Clipboard image reading stopped.'));
    reader.onload = () => resolve(new Uint8Array(reader.result as ArrayBuffer));
    reader.readAsArrayBuffer(file);
  });
}
function base64(bytes: Uint8Array) {
  const parts: string[] = [];
  for (let from = 0; from < bytes.length; from += 32768)
    parts.push(String.fromCharCode(...bytes.subarray(from, from + 32768)));
  return btoa(parts.join(''));
}

// The clipboard file becomes source, never a baseline or an independent file effect.
export function imagePaste(report: (message: string) => void, blocked: () => string | null = () => null) {
  return [imagePasteMessage.of(report), ViewPlugin.fromClass(class {
    private generation = 0;
    private request = 0;
    private alive = true;
    constructor(readonly view: EditorView) {}
    update(update: ViewUpdate) {
      if (update.docChanged || update.selectionSet || update.startState.field(sourceField) !== update.state.field(sourceField)
        || update.transactions.some(transaction => transaction.effects.length)) this.generation++;
    }
    destroy() { this.alive = false; this.generation++; }
    paste(event: ClipboardEvent) {
      const files = clipboardImageFiles(event.clipboardData);
      if (!files) return false;
      const request = ++this.request;
      this.generation++;
      if (!(event.target instanceof Element) || event.target.closest('.cm-content') !== this.view.contentDOM) return false;
      // Empty CodeMirror text paste would delete selected text. Consume rejected
      // image-only pastes too, while preserving the ordinary text route above.
      const reject = (reason: string) => { event.preventDefault(); report(reason); return true; };
      const reason = blocked() || editGuard(this.view);
      if (reason) return reject(reason);
      if (files.length !== 1 || !files[0] || !supported.has(files[0].type)) {
        return reject('Paste one PNG, JPEG, GIF, or WebP image.');
      }
      const file = files[0], edit = openLink(this.view, 'image');
      if (typeof edit === 'string') return reject(edit);
      if (edit.reference) return reject('Edit reference-image source before pasting a replacement image.');
      const selection = this.view.state.selection.main, tree = ensureSyntaxTree(this.view.state, selection.to, 50);
      if (!tree) return reject('Wait for Markdown parsing, then paste the image.');
      let protectedSource = false;
      tree.iterate({ from: selection.from, to: selection.to, enter(node) {
        if (['InlineCode', 'Link', 'Autolink', 'Frontmatter', 'FencedCode', 'CodeBlock', 'HTMLBlock', 'Table', 'LinkReference'].includes(node.name)
          && (selection.empty ? node.from < selection.from && selection.from < node.to : node.from < selection.to && node.to > selection.from)) protectedSource = true;
      } });
      if (protectedSource) return reject('Paste the image into document text.');
      if (!file.size || file.size > imageLimit || !fits(this.view, edit, file.size, file.type)) {
        return reject('The clipboard image does not fit the 8 MiB document limit.');
      }
      const generation = ++this.generation;
      const document = this.view.state.facet(imageDocument), path = this.view.state.field(imagePath, false);
      event.preventDefault();
      report('Reading clipboard image…');
      const current = () => this.alive && generation === this.generation && linkCaptureCurrent(this.view, edit)
        && this.view.state.facet(imageDocument) === document && this.view.state.field(imagePath, false) === path;
      void readImage(file).then(bytes => {
        if (!current()) { if (this.alive && request === this.request) report('The document or selection changed. Paste the image again.'); return; }
        const reason = blocked() || editGuard(this.view);
        if (reason) { report(reason); return; }
        const mime = imageMime(bytes);
        if (bytes.length !== file.size || mime !== file.type) throw new Error('The clipboard image type does not match its bytes.');
        if (!fits(this.view, edit, bytes.length, mime)) throw new Error('The image exceeds the 8 MiB document limit.');
        const transaction = planLink(this.view, edit, { label: edit.label, destination: `data:${mime};base64,${base64(bytes)}`, title: edit.title });
        if (typeof transaction === 'string') { report(transaction); return; }
        if (transaction) {
          if (size(savedSource(transaction.state.field(sourceField))) > sourceLimit) throw new Error('The image exceeds the 8 MiB document limit.');
          this.view.dispatch(transaction); this.view.focus();
        }
        report('Image pasted.');
      }).catch(error => {
        if (current()) report(`Cannot paste image: ${String(error)}`);
      });
      return true;
    }
  }, { eventHandlers: { paste(event) { return this.paste(event); } } })];
}
