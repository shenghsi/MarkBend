// @vitest-environment jsdom
import { expect, it, vi } from 'vitest';
import { fileShortcuts } from '../../src/web/file-shortcuts';

it.each([true, false])('routes platform file shortcuts and protects composition (mac=%s)', mac => {
  document.body.innerHTML = '<button id="new">New</button><button id="open">Open</button><button id="save-as">Save As</button><button id="source">Source</button><input id="field">';
  const clicks = vi.fn();
  document.querySelectorAll('button').forEach(button => button.addEventListener('click', () => clicks(button.id)));
  let composing = false;
  const dispose = fileShortcuts(document, mac, () => composing);
  const field = document.querySelector<HTMLInputElement>('#field')!;
  const key = (name: string, extra: KeyboardEventInit = {}) => {
    const event = new KeyboardEvent('keydown', { key: name, metaKey: mac, ctrlKey: !mac, bubbles: true, cancelable: true, ...extra });
    field.dispatchEvent(event); return event.defaultPrevented;
  };
  expect(key('n')).toBe(true); expect(key('o')).toBe(true); expect(key('S', { shiftKey: true })).toBe(true);
  expect(key('/')).toBe(true);
  expect(clicks.mock.calls.map(call => call[0])).toEqual(['new', 'open', 'save-as', 'source']); clicks.mockClear();
  for (const extra of [{ repeat: true }, { isComposing: true }]) expect(key('n', extra)).toBe(true);
  composing = true; key('o'); composing = false;
  field.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true })); key('n');
  expect(clicks).not.toHaveBeenCalled();
  field.dispatchEvent(new CompositionEvent('compositionend', { bubbles: true })); key('n'); expect(clicks).toHaveBeenCalledTimes(1);
  clicks.mockClear();
  expect(key('s')).toBe(false); expect(key('n', { shiftKey: true })).toBe(false);
  expect(key('o', { altKey: true })).toBe(false); expect(key('o', { metaKey: !mac, ctrlKey: mac })).toBe(false);
  expect(key('o', { metaKey: true, ctrlKey: true })).toBe(false);
  const blocked = new KeyboardEvent('keydown', { key: 'n', metaKey: mac, ctrlKey: !mac, bubbles: true, cancelable: true });
  blocked.preventDefault(); field.dispatchEvent(blocked);
  document.querySelector<HTMLButtonElement>('#open')!.disabled = true; expect(key('o')).toBe(false);
  document.querySelector('#new')!.remove(); expect(key('n')).toBe(false); expect(clicks).not.toHaveBeenCalled();
  dispose(); dispose(); expect(key('S', { shiftKey: true })).toBe(false);
});
