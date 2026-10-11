type Register = (handler: (event: { payload: unknown }) => void) => Promise<() => void>;
const commands = new Set(['new', 'open', 'save', 'save-as', 'close-document', 'print', 'undo', 'redo']);

// Menu input uses the same button handlers and guards as the document tools.
export function nativeMenu(root: Document, register: Register, allowed: (command: string) => boolean,
  report: (message: string) => void): () => void {
  let disposed = false, unlisten: (() => void) | undefined;
  void Promise.resolve().then(() => disposed ? undefined : register(event => {
    if (disposed || typeof event.payload !== 'string' || !commands.has(event.payload) || !allowed(event.payload)) return;
    const button = root.getElementById(event.payload);
    if (button instanceof HTMLButtonElement && button.isConnected && !button.disabled) button.click();
  })).then(remove => {
    if (disposed) remove?.(); else unlisten = remove;
  }).catch(reason => { if (!disposed) report(`Document menu is unavailable. Use Tools. ${String(reason)}`); });
  return () => { if (!disposed) { disposed = true; unlisten?.(); unlisten = undefined; } };
}
