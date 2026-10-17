// Use the toolbar route so keyboard commands share all file-operation guards.
export function fileShortcuts(root: Document, mac: boolean, composing: () => boolean): () => void {
  const active = new Set<EventTarget>();
  const start = (event: CompositionEvent) => { if (event.target) active.add(event.target); };
  const end = (event: CompositionEvent) => { if (event.target) active.delete(event.target); };
  const key = (event: KeyboardEvent) => {
    if (event.defaultPrevented || event.altKey) return;
    const name = event.key.toLowerCase();
    const isSlash = !event.shiftKey && (name === '/' || event.code === 'Slash') && (event.metaKey || event.ctrlKey);
    const isMod = mac ? (!event.metaKey || event.ctrlKey) : (!event.ctrlKey || event.metaKey);
    if (!isSlash && isMod) return;
    const id = !event.shiftKey && name === 'n' ? 'new' : !event.shiftKey && name === 'o' ? 'open'
      : event.shiftKey && name === 's' ? 'save-as'
      : isSlash ? 'source' : undefined;
    if (!id) return;
    const button = root.getElementById(id) as HTMLButtonElement | null;
    if (!button?.isConnected || button.disabled) return;
    event.preventDefault();
    event.stopPropagation();
    if (event.repeat || event.isComposing || composing() || [...active].some(target => target instanceof Node && target.isConnected)) return;
    button.click();
  };
  root.addEventListener('compositionstart', start, true);
  root.addEventListener('compositionend', end, true);
  // Table widgets stop bubbling keys. Capture only these native file shortcuts.
  root.addEventListener('keydown', key, true);
  return () => {
    root.removeEventListener('compositionstart', start, true);
    root.removeEventListener('compositionend', end, true);
    root.removeEventListener('keydown', key, true); active.clear();
  };
}
