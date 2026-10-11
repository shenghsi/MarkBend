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
export function fileSidebar(pane: HTMLElement, services: SidebarServices) {
  let root = '', active = '', generation = 0, disposed = false, choosing = false;
  const requests = new WeakMap<HTMLElement, number>();
  const heading = document.createElement('div'); heading.className = 'files-heading'; heading.textContent = 'FILES';
  const actions = document.createElement('div'); actions.className = 'files-actions';
  const choose = document.createElement('button'); choose.textContent = 'Open folder';
  const refresh = document.createElement('button'); refresh.textContent = 'Refresh files'; refresh.disabled = true;
  const label = document.createElement('div'); label.className = 'files-root';
  const body = document.createElement('div'); body.className = 'files-list';
  actions.append(choose, refresh); pane.append(heading, actions, label, body);
  function message(parent: HTMLElement, text: string) {
    const value = document.createElement('p'); value.textContent = text; value.setAttribute('role', 'status'); parent.append(value);
  }
  async function load(path: string, parent: HTMLElement, owner: () => boolean) {
    const request = (requests.get(parent) || 0) + 1; requests.set(parent, request);
    const current = () => owner() && requests.get(parent) === request;
    parent.replaceChildren(); message(parent, 'Loading files…');
    try {
      const listing = await services.read(path); if (!current()) return;
      parent.replaceChildren();
      for (const warning of listing.warnings) message(parent, warning);
      if (!listing.entries.length) message(parent, 'No Markdown files or folders.');
      const list = document.createElement('ul'); parent.append(list);
      for (const entry of listing.entries) {
        const item = document.createElement('li'), button = document.createElement('button');
        button.textContent = entry.name; button.title = entry.path; item.append(button); list.append(item);
        if (!entry.directory) {
          button.dataset.filePath = entry.path;
          if (entry.path === active) button.setAttribute('aria-current', 'page');
          button.addEventListener('click', () => { if (current() && services.allowed()) services.open(entry.path); });
          continue;
        }
        let expanded = false, token = 0;
        const children = document.createElement('div'); children.hidden = true; item.append(children);
        button.className = 'files-folder'; button.setAttribute('aria-expanded', 'false');
        button.addEventListener('click', () => {
          if (!current() || !services.allowed()) return;
          expanded = !expanded; children.hidden = !expanded; button.setAttribute('aria-expanded', String(expanded));
          const request = ++token;
          if (expanded) void load(entry.path, children, () => current() && expanded && token === request);
        });
      }
    } catch (error) {
      if (!current()) return;
      parent.replaceChildren(); message(parent, String(error));
      const retry = document.createElement('button'); retry.textContent = 'Retry folder'; parent.append(retry);
      retry.addEventListener('click', () => { if (current() && services.allowed()) void load(path, parent, owner); });
    }
  }
  function render() {
    const request = ++generation;
    label.textContent = root; label.title = root; refresh.disabled = !root;
    if (root) void load(root, body, () => !disposed && generation === request);
    else { body.replaceChildren(); message(body, 'Choose a folder to show Markdown files.'); }
  }
  choose.addEventListener('click', async () => {
    if (disposed || choosing || !services.allowed()) return;
    choosing = true; choose.disabled = true;
    try {
      const selected = await services.choose();
      if (!disposed && selected && services.allowed()) { root = selected; render(); }
    } catch (error) { if (!disposed) message(body, String(error)); }
    finally { choosing = false; choose.disabled = false; }
  });
  refresh.addEventListener('click', () => { if (!disposed && services.allowed() && root) render(); });
  render();
  return { dispose() { disposed = true; generation++; }, root: () => root,
    select(path: string) {
      active = path;
      pane.querySelectorAll<HTMLButtonElement>('button[data-file-path]').forEach(button => {
        if (button.dataset.filePath === path) button.setAttribute('aria-current', 'page');
        else button.removeAttribute('aria-current');
      });
    } };
}
