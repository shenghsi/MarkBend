// @vitest-environment jsdom
import { expect, it, vi } from 'vitest';

it('triggers startDragging only for non-interactive elements in documentBar', () => {
  const documentBar = document.createElement('div');
  documentBar.className = 'document-bar';

  const title = document.createElement('span');
  title.id = 'document-title';
  title.textContent = 'My Note';

  const button = document.createElement('button');
  button.id = 'files-toggle';
  button.textContent = 'Files';

  documentBar.append(title, button);
  document.body.append(documentBar);

  const startDragging = vi.fn().mockResolvedValue(undefined);

  documentBar.addEventListener('mousedown', event => {
    if (event.button !== 0) return;
    const target = event.target as HTMLElement | null;
    if (target && !target.closest('button, input, select, textarea, a, .outline-dropdown')) {
      void startDragging();
    }
  });

  // 1. Click on title bar text -> drags
  title.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, button: 0 }));
  expect(startDragging).toHaveBeenCalledTimes(1);

  // 2. Click on empty bar area -> drags
  documentBar.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, button: 0 }));
  expect(startDragging).toHaveBeenCalledTimes(2);

  // 3. Click on button -> does NOT drag
  button.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, button: 0 }));
  expect(startDragging).toHaveBeenCalledTimes(2);

  // 4. Right click on title -> does NOT drag
  title.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, button: 2 }));
  expect(startDragging).toHaveBeenCalledTimes(2);
});
