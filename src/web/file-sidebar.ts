export interface FolderEntry { name: string; path: string; directory: boolean }
export interface FolderListing { entries: FolderEntry[]; warnings: string[] }
export interface SidebarServices {
  read(path: string): Promise<FolderListing>;
  choose(): Promise<string | null>;
  open(path: string): void;
  allowed(): boolean;
}

// Each mounted folder owns its request token. A root refresh removes all older
// owners; collapse invalidates only that folder's pending publication.
export function fileSidebar(pane: HTMLElement, services: SidebarServices,
  options: { root?: string; deferRead?: boolean; rootChanged?: (root: string) => void; switchView?: (view: 'files' | 'outline') => void; showHeading?: boolean } = {}) {
  let root = options.root || '', active = '', generation = 0, disposed = false, choosing = false;
  let deferredRead = !!options.deferRead, persistRoot = false;
  const requests = new WeakMap<HTMLElement, number>();
  const parentFolders = new WeakMap<HTMLButtonElement, HTMLButtonElement>();
  const folderChildren = new WeakMap<HTMLButtonElement, HTMLElement>();
  const expandedPaths = new Set<string>();
  const heading = document.createElement('div');
  if (options.switchView) {
    heading.className = 'sidebar-header files-heading';
    const tabs = document.createElement('div');
    tabs.className = 'sidebar-tabs';
    const outlineTab = document.createElement('button');
    outlineTab.type = 'button';
    outlineTab.className = 'sidebar-tab-btn sidebar-tab-outline';
    outlineTab.title = 'Outline';
    outlineTab.setAttribute('aria-label', 'Outline');
    outlineTab.addEventListener('click', () => { options.switchView?.('outline'); });
    tabs.append(outlineTab);
    const title = document.createElement('span');
    title.className = 'sidebar-title';
    title.textContent = 'FILES';
    heading.append(tabs, title);
  } else {
    heading.className = 'files-heading';
    heading.textContent = 'FILES';
  }
  const actions = document.createElement('div'); actions.className = 'files-actions';
  const choose = document.createElement('button'); choose.textContent = 'Open folder';
  const refresh = document.createElement('button'); refresh.textContent = 'Refresh files'; refresh.disabled = true;
  const icon = (directory: boolean) => {
    const value = document.createElement('span');
    value.className = `files-icon ${directory ? 'files-icon-folder' : 'files-icon-document'}`;
    value.setAttribute('aria-hidden', 'true'); return value;
  };
  const label = document.createElement('div'); label.className = 'files-root';
  const rootName = document.createElement('span'); label.append(icon(true), rootName);
  const body = document.createElement('div'); body.className = 'files-list';
  pane.setAttribute('aria-description', 'Arrow Up and Down move through files. Arrow Right opens a folder or moves to its children. Arrow Left closes a folder or moves to its parent. Home and End move to the first and last entries. Enter opens the focused file.');
  actions.append(choose, refresh);
  if (options.showHeading !== false) {
    pane.append(heading, actions, label, body);
  } else {
    pane.append(actions, label, body);
  }
  const visible = (button: HTMLButtonElement) => button.isConnected && body.contains(button) && !button.closest('[hidden]');
  const entries = (parent: HTMLElement = body) => Array.from(parent.querySelectorAll<HTMLButtonElement>('button[data-sidebar-entry]')).filter(visible);
  function keydown(event: KeyboardEvent) {
    if (disposed || event.defaultPrevented || event.isComposing || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
    if (!['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
    const button = event.target;
    if (!(button instanceof HTMLButtonElement) || !visible(button) || !services.allowed()) return;
    const buttons = entries(), index = buttons.indexOf(button); if (index < 0) return;
    let target: HTMLButtonElement | undefined;
    if (event.key === 'ArrowUp') target = buttons[Math.max(0, index - 1)];
    else if (event.key === 'ArrowDown') target = buttons[Math.min(buttons.length - 1, index + 1)];
    else if (event.key === 'Home') target = buttons[0];
    else if (event.key === 'End') target = buttons[buttons.length - 1];
    else if (event.key === 'ArrowRight') {
      const children = folderChildren.get(button);
      if (children) {
        if (button.getAttribute('aria-expanded') === 'false') button.click();
        else target = entries(children)[0];
      }
    } else if (button.getAttribute('aria-expanded') === 'true') button.click();
    else target = parentFolders.get(button);
    event.preventDefault();
    if (target && visible(target)) target.focus();
  }
  body.addEventListener('keydown', keydown);
  function message(parent: HTMLElement, text: string) {
    const value = document.createElement('p'); value.textContent = text; value.setAttribute('role', 'status'); parent.append(value);
  }
  async function load(path: string, parent: HTMLElement, owner: () => boolean, folder?: HTMLButtonElement, accepted?: () => void) {
    const request = (requests.get(parent) || 0) + 1; requests.set(parent, request);
    const current = () => owner() && requests.get(parent) === request;
    function clear() {
      if (parent.contains(document.activeElement)) (folder || (refresh.disabled ? choose : refresh)).focus();
      parent.replaceChildren();
    }
    clear(); message(parent, 'Loading files…');
    try {
      const listing = await services.read(path); if (!current()) return;
      accepted?.();
      clear();
      for (const warning of listing.warnings) message(parent, warning);
      if (!listing.entries.length) message(parent, 'No Markdown files or folders.');
      const list = document.createElement('ul'); parent.append(list);
      for (const entry of listing.entries) {
        const item = document.createElement('li'), button = document.createElement('button');
        button.dataset.sidebarEntry = ''; if (folder) parentFolders.set(button, folder);
        const name = document.createElement('span'); name.className = 'files-entry-name'; name.textContent = entry.name;
        const caret = document.createElement('span'); caret.className = 'files-caret'; caret.setAttribute('aria-hidden', 'true');
        button.append(caret, icon(entry.directory), name); button.title = entry.path; item.append(button); list.append(item);
        if (!entry.directory) {
          button.dataset.filePath = entry.path;
          if (entry.path === active) button.setAttribute('aria-current', 'page');
          button.addEventListener('click', () => { if (current() && services.allowed()) services.open(entry.path); });
          continue;
        }
        let expanded = expandedPaths.has(entry.path), token = 0;
        const children = document.createElement('div'); children.hidden = !expanded; item.append(children);
        folderChildren.set(button, children);
        button.className = 'files-folder'; button.setAttribute('aria-expanded', String(expanded));
        if (expanded) {
          const request = ++token;
          void load(entry.path, children, () => current() && expanded && token === request, button);
        }
        button.addEventListener('click', () => {
          if (!current() || !services.allowed()) return;
          if (expanded && children.contains(document.activeElement)) button.focus();
          expanded = !expanded; children.hidden = !expanded; button.setAttribute('aria-expanded', String(expanded));
          if (expanded) expandedPaths.add(entry.path);
          else expandedPaths.delete(entry.path);
          const request = ++token;
          if (expanded) void load(entry.path, children, () => current() && expanded && token === request, button);
        });
      }
    } catch (error) {
      if (!current()) return;
      clear(); message(parent, String(error));
      const retry = document.createElement('button'); retry.textContent = 'Retry folder'; parent.append(retry);
      retry.dataset.sidebarEntry = ''; if (folder) parentFolders.set(retry, folder);
      retry.addEventListener('click', () => { if (current() && services.allowed()) void load(path, parent, owner, folder, accepted); });
    }
  }
  function render() {
    const request = ++generation;
    // Unix names can contain a literal backslash. Only Windows paths use both
    // separator forms. Display changes never alter the host path.
    const parts = root.split(root.startsWith('/') ? '/' : /[\\/]/).filter(Boolean);
    rootName.textContent = parts.length === 1 && /^[A-Za-z]:$/.test(parts[0]) ? root : parts[parts.length - 1] || root;
    label.title = root; label.hidden = !root; refresh.disabled = !root;
    if (root && !deferredRead) void load(root, body, () => !disposed && generation === request, undefined, () => {
      if (persistRoot) { persistRoot = false; options.rootChanged?.(root); }
    });
    else { body.replaceChildren(); message(body, 'Choose a folder to show Markdown files.'); }
  }
  choose.addEventListener('click', async () => {
    if (disposed || choosing || !services.allowed()) return;
    choosing = true; choose.disabled = true;
    try {
      const selected = await services.choose();
      if (!disposed && selected && services.allowed()) { root = selected; persistRoot = true; render(); }
    } catch (error) { if (!disposed) message(body, String(error)); }
    finally { choosing = false; choose.disabled = false; }
  });
  refresh.addEventListener('click', () => { if (!disposed && services.allowed() && root) render(); });
  render();
  return { dispose() { disposed = true; generation++; body.removeEventListener('keydown', keydown); }, root: () => root,
    show() { if (!disposed && deferredRead) { deferredRead = false; render(); } },
    refresh() { if (!disposed && services.allowed() && root) render(); },
    select(path: string) {
      active = path;
      pane.querySelectorAll<HTMLButtonElement>('button[data-file-path]').forEach(button => {
        if (button.dataset.filePath === path) button.setAttribute('aria-current', 'page');
        else button.removeAttribute('aria-current');
      });
    } };
}
