import type { DragDropEvent } from '@tauri-apps/api/window';

type Register = (handler: (event: { payload: DragDropEvent }) => void) => Promise<() => void>;

// Native paths are literal file paths. The extension only selects this workflow;
// the desktop host still validates the file and its source bytes.
export function droppedDocument(paths: readonly string[]): string | undefined {
  if (paths.length !== 1) return;
  const path = paths[0], name = path.split(/[\\/]/).pop() || '';
  return path && !path.includes('\0') && /\.(md|markdown|txt)$/i.test(name) ? path : undefined;
}

export function fileDrops(register: Register, open: (path: string) => void, report: (message: string) => void,
  affordance: (visible: boolean) => void): () => void {
  let disposed = false, unlisten: (() => void) | undefined;
  void Promise.resolve().then(() => register(event => {
    if (disposed) return;
    const payload = event.payload;
    if (payload.type === 'enter') affordance(!!droppedDocument(payload.paths));
    else if (payload.type === 'leave') affordance(false);
    else if (payload.type === 'drop') {
      affordance(false);
      const path = droppedDocument(payload.paths);
      if (path) open(path); else report('Drop one Markdown or text file to open it.');
    }
  })).then(remove => {
    if (disposed) remove(); else unlisten = remove;
  }).catch(error => {
    if (!disposed) { affordance(false); report(`File drop is unavailable. Use Open. ${String(error)}`); }
  });
  return () => { if (!disposed) { disposed = true; affordance(false); unlisten?.(); } };
}
