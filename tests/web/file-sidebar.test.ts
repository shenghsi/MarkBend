// @vitest-environment jsdom
import { expect, it, vi } from 'vitest';
import { fileSidebar, FolderListing } from '../../src/web/file-sidebar';
const deferred = <T>() => { let resolve!: (value: T) => void; const promise = new Promise<T>(done => { resolve = done; }); return { promise, resolve }; };
const listing = (name: string): FolderListing => ({ entries: [{ name, path: `/root/${name}`, directory: false }], warnings: [] });
const button = (pane: HTMLElement, name: string) => Array.from(pane.querySelectorAll('button')).find(value => value.textContent === name)!;

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
