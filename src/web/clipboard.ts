import { Facet } from '@codemirror/state';

export const imagePasteMessage = Facet.define<(message: string) => void, ((message: string) => void) | undefined>({ combine: callbacks => callbacks[0] });
export function clipboardImageFiles(data: DataTransfer | null): (File | null)[] | undefined {
  if (!data || data.getData('text/plain') || data.getData('text/html') || data.getData('text/uri-list')) return;
  const files = Array.from(data.items).filter(item => item.kind === 'file').map(item => item.getAsFile());
  if (files.some(file => file?.type.startsWith('image/'))) return files;
}
