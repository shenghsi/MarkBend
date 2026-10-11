// @vitest-environment jsdom
import { afterEach, expect, it, vi } from 'vitest';
import { fileSidebar, FolderListing } from '../../src/web/file-sidebar';
const deferred = <T>() => { let resolve!: (value: T) => void; const promise = new Promise<T>(done => { resolve = done; }); return { promise, resolve }; };
const listing = (name: string): FolderListing => ({ entries: [{ name, path: `/root/${name}`, directory: false }], warnings: [] });
const button = (pane: HTMLElement, name: string) => Array.from(pane.querySelectorAll('button')).find(value => value.textContent === name)!;
afterEach(() => document.body.replaceChildren());
const key = (button: HTMLButtonElement, value: string, extra: KeyboardEventInit = {}) => {
  const event = new KeyboardEvent('keydown', { key: value, bubbles: true, cancelable: true, ...extra });
  button.dispatchEvent(event); return event;
};

it('moves through visible nested entries and keeps literal Windows paths on Open', async () => {
  const pane = document.createElement('aside'); document.body.append(pane);
  const root = 'C:\\日本語%20', folderPath = root + '\\folder', nestedPath = folderPath + '\\nested', filePath = nestedPath + '\\中文.md';
  const read = vi.fn(async (path: string): Promise<FolderListing> => ({ warnings: [], entries:
    path === root ? [{ name: 'folder', path: folderPath, directory: true }, { name: 'last.md', path: root + '\\last.md', directory: false }] :
    path === folderPath ? [{ name: 'nested', path: nestedPath, directory: true }, { name: 'child.md', path: folderPath + '\\child.md', directory: false }] :
    [{ name: '中文.md', path: filePath, directory: false }] }));
  const open = vi.fn(), sidebar = fileSidebar(pane, { read, open, choose: async () => root, allowed: () => true });
  try {
    button(pane, 'Open folder').click(); await vi.waitFor(() => expect(button(pane, 'folder')).toBeDefined());
    const folder = button(pane, 'folder'), last = button(pane, 'last.md'); folder.focus();
    key(folder, 'ArrowDown'); expect(document.activeElement).toBe(last);
    key(last, 'Home'); expect(document.activeElement).toBe(folder);
    key(folder, 'ArrowRight'); expect(document.activeElement).toBe(folder);
    await vi.waitFor(() => expect(button(pane, 'nested')).toBeDefined());
    key(folder, 'ArrowRight'); const nested = button(pane, 'nested'); expect(document.activeElement).toBe(nested);
    key(nested, 'ArrowRight'); await vi.waitFor(() => expect(button(pane, '中文.md')).toBeDefined());
    key(nested, 'ArrowRight'); const file = button(pane, '中文.md'); expect(document.activeElement).toBe(file);
    file.click(); expect(open).toHaveBeenCalledWith(filePath);
    key(file, 'ArrowDown'); expect(document.activeElement).toBe(button(pane, 'child.md'));
    key(button(pane, 'child.md'), 'End'); expect(document.activeElement).toBe(last);
    key(last, 'ArrowUp'); expect(document.activeElement).toBe(button(pane, 'child.md'));
    key(button(pane, 'child.md'), 'ArrowLeft'); expect(document.activeElement).toBe(folder);
    key(folder, 'ArrowLeft'); expect(folder.getAttribute('aria-expanded')).toBe('false');
    key(folder, 'ArrowDown'); expect(document.activeElement).toBe(last);
    expect(read.mock.calls.map(([path]) => path)).toEqual([root, folderPath, nestedPath]);
  } finally { sidebar.dispose(); }
});

it('guards keyboard focus during composition, busy state, hidden state and disposal', async () => {
  const pane = document.createElement('aside'); document.body.append(pane); let allowed = true;
  const read = vi.fn().mockResolvedValue({ entries: [{ name: 'folder', path: '/root/folder', directory: true },
    { name: 'file.md', path: '/root/file.md', directory: false }], warnings: [] });
  const sidebar = fileSidebar(pane, { read, open: vi.fn(), choose: async () => '/root', allowed: () => allowed });
  button(pane, 'Open folder').click(); await vi.waitFor(() => expect(button(pane, 'folder')).toBeDefined());
  const folder = button(pane, 'folder'); folder.focus();
  for (const extra of [{ isComposing: true }, { altKey: true }, { ctrlKey: true }, { metaKey: true }, { shiftKey: true }]) {
    expect(key(folder, 'ArrowRight', extra).defaultPrevented).toBe(false);
    expect(folder.getAttribute('aria-expanded')).toBe('false'); expect(document.activeElement).toBe(folder);
  }
  allowed = false; expect(key(folder, 'End').defaultPrevented).toBe(false); expect(document.activeElement).toBe(folder);
  allowed = true; pane.hidden = true; expect(key(folder, 'ArrowRight').defaultPrevented).toBe(false);
  pane.hidden = false; sidebar.dispose(); expect(key(folder, 'ArrowRight').defaultPrevented).toBe(false);
  expect(read).toHaveBeenCalledTimes(1);
});

it('keeps focus safe during loading, retry, empty folders, collapse, and root refresh', async () => {
  const pane = document.createElement('aside'); document.body.append(pane);
  const pending = deferred<FolderListing>(), refreshed = deferred<FolderListing>();
  const read = vi.fn().mockResolvedValueOnce({ entries: [{ name: 'folder', path: '/root/folder', directory: true }], warnings: [] })
    .mockReturnValueOnce(pending.promise).mockResolvedValueOnce({ entries: [], warnings: [] }).mockReturnValueOnce(refreshed.promise);
  const sidebar = fileSidebar(pane, { read, open: vi.fn(), choose: async () => '/root', allowed: () => true });
  try {
    button(pane, 'Open folder').click(); await vi.waitFor(() => expect(button(pane, 'folder')).toBeDefined());
    const folder = button(pane, 'folder'); folder.focus(); key(folder, 'ArrowRight'); key(folder, 'ArrowRight');
    expect(document.activeElement).toBe(folder); expect(read).toHaveBeenCalledTimes(2);
    const input = document.createElement('input'); document.body.append(input); input.focus();
    pending.resolve({ entries: [{ name: 'child.md', path: '/root/folder/child.md', directory: false }], warnings: [] });
    await vi.waitFor(() => expect(button(pane, 'child.md')).toBeDefined()); expect(document.activeElement).toBe(input);
    button(pane, 'child.md').focus(); folder.click(); expect(document.activeElement).toBe(folder);
    key(folder, 'ArrowRight'); await vi.waitFor(() => expect(pane.textContent).toContain('No Markdown'));
    key(folder, 'ArrowRight'); expect(document.activeElement).toBe(folder);
    button(pane, 'Refresh files').click(); expect(document.activeElement).toBe(button(pane, 'Refresh files'));
    refreshed.resolve({ entries: [], warnings: [] }); await Promise.resolve();
    expect(document.activeElement).toBe(button(pane, 'Refresh files'));
  } finally { sidebar.dispose(); }
});

it('includes Retry in keyboard navigation and returns focus to its folder before retry', async () => {
  const pane = document.createElement('aside'); document.body.append(pane);
  const read = vi.fn().mockResolvedValueOnce({ entries: [{ name: 'folder', path: '/root/folder', directory: true }], warnings: [] })
    .mockRejectedValueOnce('Read failed').mockResolvedValueOnce(listing('new.md'));
  const sidebar = fileSidebar(pane, { read, open: vi.fn(), choose: async () => '/root', allowed: () => true });
  try {
    button(pane, 'Open folder').click(); await vi.waitFor(() => expect(button(pane, 'folder')).toBeDefined());
    const folder = button(pane, 'folder'); folder.focus(); key(folder, 'ArrowRight');
    await vi.waitFor(() => expect(button(pane, 'Retry folder')).toBeDefined());
    key(folder, 'ArrowRight'); const retry = button(pane, 'Retry folder'); expect(document.activeElement).toBe(retry);
    key(retry, 'ArrowLeft'); expect(document.activeElement).toBe(folder);
    key(folder, 'End'); expect(document.activeElement).toBe(retry);
    retry.click(); expect(document.activeElement).toBe(folder);
    await vi.waitFor(() => expect(button(pane, 'new.md')).toBeDefined()); expect(document.activeElement).toBe(folder);
  } finally { sidebar.dispose(); }
});

it('retains literal Unicode paths, opens files, and blocks controls during input', async () => {
  const pane = document.createElement('aside'), open = vi.fn(), read = vi.fn().mockResolvedValue(listing('<日本語%20.md>'));
  let allowed = true;
  const sidebar = fileSidebar(pane, { read, open, choose: async () => '/root/日本語%20', allowed: () => allowed });
  button(pane, 'Open folder').click(); await vi.waitFor(() => expect(read).toHaveBeenCalledWith('/root/日本語%20'));
  expect(pane.querySelector('img')).toBeNull(); button(pane, '<日本語%20.md>').click();
  expect(open).toHaveBeenCalledWith('/root/<日本語%20.md>'); allowed = false;
  button(pane, '<日本語%20.md>').click(); button(pane, 'Refresh files').click();
  expect(open).toHaveBeenCalledTimes(1); expect(read).toHaveBeenCalledTimes(1);
  sidebar.dispose(); button(pane, '<日本語%20.md>').click(); expect(open).toHaveBeenCalledTimes(1);
});

it('rejects old root and refresh results and results after disposal', async () => {
  const pane = document.createElement('aside'), first = deferred<FolderListing>(), second = deferred<FolderListing>(), third = deferred<FolderListing>();
  const read = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise).mockReturnValueOnce(third.promise);
  let chosen = '/first';
  const sidebar = fileSidebar(pane, { read, open: vi.fn(), choose: async () => chosen, allowed: () => true });
  button(pane, 'Open folder').click(); await vi.waitFor(() => expect(read).toHaveBeenCalledTimes(1));
  chosen = '/second'; button(pane, 'Open folder').click(); await vi.waitFor(() => expect(read).toHaveBeenCalledTimes(2));
  second.resolve(listing('new.md')); await vi.waitFor(() => expect(pane.textContent).toContain('new.md'));
  first.resolve(listing('old.md')); await Promise.resolve(); expect(pane.textContent).not.toContain('old.md');
  button(pane, 'Refresh files').click(); sidebar.dispose(); third.resolve(listing('disposed.md'));
  await Promise.resolve(); expect(pane.textContent).not.toContain('disposed.md');
});

it('does not reopen collapsed folders or publish old expansion results', async () => {
  const pane = document.createElement('aside'), first = deferred<FolderListing>(), second = deferred<FolderListing>();
  const read = vi.fn().mockResolvedValueOnce({ entries: [{ name: 'folder', path: '/root/folder', directory: true }], warnings: [] })
    .mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
  const sidebar = fileSidebar(pane, { read, open: vi.fn(), choose: async () => '/root', allowed: () => true });
  button(pane, 'Open folder').click(); await vi.waitFor(() => expect(button(pane, 'folder')).toBeDefined());
  const folder = button(pane, 'folder'); folder.click(); folder.click();
  first.resolve(listing('old.md')); await Promise.resolve(); expect(folder.getAttribute('aria-expanded')).toBe('false');
  expect(pane.textContent).not.toContain('old.md'); folder.click(); second.resolve(listing('new.md'));
  await vi.waitFor(() => expect(pane.textContent).toContain('new.md')); expect(folder.getAttribute('aria-expanded')).toBe('true');
  sidebar.dispose();
});

it('shows read errors and scan notices and retries a failed folder', async () => {
  const pane = document.createElement('aside'), read = vi.fn().mockRejectedValueOnce('<Read failed>')
    .mockResolvedValueOnce({ entries: [], warnings: ['The list is incomplete.'] });
  const sidebar = fileSidebar(pane, { read, open: vi.fn(), choose: async () => '/root', allowed: () => true });
  button(pane, 'Open folder').click(); await vi.waitFor(() => expect(pane.textContent).toContain('<Read failed>'));
  button(pane, 'Retry folder').click(); await vi.waitFor(() => expect(pane.textContent).toContain('incomplete'));
  expect(read).toHaveBeenCalledTimes(2); sidebar.dispose();
});

it('retains the root on cancelled choice and rejects choice completed after disposal', async () => {
  const pane = document.createElement('aside'), pending = deferred<string | null>();
  const choose = vi.fn().mockResolvedValueOnce('/root').mockResolvedValueOnce(null).mockReturnValueOnce(pending.promise);
  const read = vi.fn().mockResolvedValue(listing('doc.md'));
  const sidebar = fileSidebar(pane, { read, open: vi.fn(), choose, allowed: () => true });
  button(pane, 'Open folder').click(); await vi.waitFor(() => expect(read).toHaveBeenCalledTimes(1));
  button(pane, 'Open folder').click(); await vi.waitFor(() => expect(choose).toHaveBeenCalledTimes(2));
  expect(sidebar.root()).toBe('/root'); expect(read).toHaveBeenCalledTimes(1);
  await Promise.resolve(); button(pane, 'Open folder').click(); sidebar.dispose(); pending.resolve('/late');
  await Promise.resolve(); expect(sidebar.root()).toBe('/root');
});
