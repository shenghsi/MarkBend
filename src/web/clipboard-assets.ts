import { invoke } from '@tauri-apps/api/core';
import { EditorView } from '@codemirror/view';
import { ClipboardPolicy } from './clipboard';
import { copyImageBytes, ImageCopyError } from './image-assets';
import { imageDocument, imagePath, imageFileDestination } from './images';

// Encoding the complete document path is larger than encoding its file stem.
// The extra name space bounds both current host naming schemes without copying
// Rust file_stem rules into the renderer. This path is never read or published.
export function clipboardPlaceholder(path: string): string {
  return 'clipboard-' + imageFileDestination(encodeURIComponent(path)) + '.assets/image-' + '0'.repeat(64) + '.webp';
}
export function clipboardImageControls(parent: HTMLElement, options: {
  native: boolean;
  available: (view: EditorView) => string | null;
  call?: typeof invoke;
  storage?: Pick<Storage, 'getItem' | 'setItem'>;
}) {
  let storage = options.storage;
  if (!storage) { try { storage = localStorage; } catch { /* The preference still works without storage. */ } }
  let mode = 'embed', generation = 0;
  try { if (options.native && storage?.getItem('markbend-pasted-images') === 'copy') mode = 'copy'; } catch { /* Use Embed. */ }
  const label = document.createElement('label'); label.textContent = 'Pasted images ';
  const select = document.createElement('select'); select.setAttribute('aria-label', 'Pasted images');
  select.innerHTML = '<option value="embed">Embed in Markdown</option><option value="copy">Copy beside document</option>';
  select.options[1].disabled = !options.native; select.value = mode; label.append(select); parent.append(label);
  const hint = document.createElement('span'); hint.textContent = 'Copy requires a saved document. Undo keeps copied files.';
  hint.hidden = mode !== 'copy'; parent.append(hint);
  const notice = document.createElement('span'); notice.className = 'image-copy-notice'; notice.setAttribute('role', 'status'); notice.hidden = true; parent.append(notice);
  select.addEventListener('change', () => {
    mode = options.native && select.value === 'copy' ? 'copy' : 'embed'; select.value = mode; generation++;
    hint.hidden = mode !== 'copy';
    try { storage?.setItem('markbend-pasted-images', mode); } catch { /* Keep the session preference. */ }
  });
  const capture: ClipboardPolicy = view => {
    const captured = generation, selected = mode, id = view.state.facet(imageDocument), path = view.state.field(imagePath, false);
    const current = () => generation === captured && mode === selected && view.state.facet(imageDocument) === id && view.state.field(imagePath, false) === path;
    if (selected === 'embed') return { kind: 'embed', current };
    const reason = options.available(view); if (reason) return reason;
    if (!options.native || id === undefined || !path) return 'Save the document before copying pasted images.';
    return { kind: 'copy', current, placeholder: clipboardPlaceholder(path),
      publish: async (bytes, requestCurrent, blocked) => {
        try {
          const destination = await copyImageBytes(view, bytes, () => current() && requestCurrent(),
            () => blocked() || !!options.available(view), options.call);
          if (destination === null) return null;
          notice.hidden = false; notice.textContent = `Image copied for ${path}: ${destination}. Cancelled paste and Undo keep the file.`;
          // A copied asset is always a relative path. Encode filename punctuation
          // once and protect table delimiters before package insertion checks.
          const parts = destination.split('/');
          if (parts.length !== 2 || !parts[0].endsWith('.assets') || parts[0].includes('\0') ||
            !/^image-[a-z0-9]{1,64}\.(png|jpg|gif|webp)$/i.test(parts[1]))
            throw new ImageCopyError('The copy returned an invalid relative path. The copied file may remain.');
          const encoded = imageFileDestination(destination).replace(/\|/g, '%7C').replace(/\\/g, '%5C');
          if (new TextEncoder().encode(encoded).length > new TextEncoder().encode(clipboardPlaceholder(path)).length)
            throw new ImageCopyError('The copy path exceeds its source-size reservation. The copied file remains.');
          return encoded;
        } catch (error) {
          if (error instanceof ImageCopyError) {
            notice.hidden = false; notice.textContent = `Image copy for ${path}: ${String(error)}. Inspect the image folder before retrying.`;
          }
          throw error;
        }
      },
    };
  };
  return { capture, select, notice };
}
