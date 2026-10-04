import { EditorView } from '@codemirror/view';
import { applyLink, LinkEdit, linkCaptureCurrent, openLink, removeLink } from './links';
import { editGuard } from './edit-guard';
import { imageFileDestination } from './images';

export function linkControls(view: EditorView, parent: HTMLElement, report: (message: string) => void,
  kind: 'link' | 'image' = 'link', choose?: () => Promise<string | null>) {
  const name = kind === 'image' ? 'Image' : 'Link';
  const form = document.createElement('form');
  form.className = `link-controls${kind === 'image' ? ' image-controls' : ''}`; form.hidden = true; form.setAttribute('aria-label', `${name} controls`);
  form.innerHTML = `<label>${kind === 'image' ? 'Alt text (Markdown)' : 'Text'}<input name="label" aria-label="${name}${kind === 'image' ? ' alt' : ''} text"></label><label>Destination<input name="destination" aria-label="${name} destination"></label><label>Title (optional)<input name="title" aria-label="${name} title"></label><button type="submit">Apply ${name}</button><button type="button" data-remove>Remove ${name}</button>${choose ? '<button type="button" data-choose>Choose Image</button>' : ''}<button type="button" data-cancel>Cancel</button><span class="link-hint"></span>`;
  parent.after(form);
  const field = (name: string) => form.elements.namedItem(name) as HTMLInputElement;
  const apply = form.querySelector<HTMLButtonElement>('[type="submit"]')!, remove = form.querySelector<HTMLButtonElement>('[data-remove]')!;
  let edit: LinkEdit | undefined, composing = false, request = 0;
  const close = () => { request++; edit = undefined; form.hidden = true; composing = false; view.requestMeasure(); view.focus(); };
  const commit = (removeOnly = false) => {
    if (!edit) return;
    if (composing) { report(`Finish text input, then apply the ${kind} command.`); return; }
    const reason = removeOnly ? removeLink(view, edit) : applyLink(view, edit, {
      label: field('label').value, destination: field('destination').value, title: field('title').value });
    if (reason) report(reason); else close();
  };
  form.addEventListener('submit', event => { event.preventDefault(); commit(); });
  remove.addEventListener('click', () => commit(true));
  form.querySelector('[data-cancel]')!.addEventListener('click', close);
  form.addEventListener('keydown', event => {
    // A composing Enter must not submit the form, including when the browser
    // supplies only the key's composition flag.
    if (event.key === 'Enter' && (composing || event.isComposing)) { event.preventDefault(); return; }
    if (event.key === 'Escape' && !composing && !event.isComposing) { event.preventDefault(); close(); }
  });
  form.addEventListener('compositionstart', () => { composing = true; });
  form.addEventListener('compositionend', () => { composing = false; });
  const picker = form.querySelector<HTMLButtonElement>('[data-choose]');
  form.addEventListener('input', () => { request++; if (picker) picker.disabled = !!edit?.reference; });
  picker?.addEventListener('click', () => {
    if (!edit || !choose || composing) return;
    const reason = editGuard(view); if (reason) { report(reason); return; }
    const captured = edit, token = ++request; picker.disabled = true;
    const current = () => token === request && edit === captured && !form.hidden && !composing && linkCaptureCurrent(view, captured) && !editGuard(view);
    void choose().then(path => {
      if (path && current()) { field('destination').value = imageFileDestination(path); field('destination').focus(); }
    }, error => { if (current()) report(String(error)); }).finally(() => { if (token === request) picker.disabled = !!edit?.reference; });
  });
  return () => {
    const result = openLink(view, kind);
    if (typeof result === 'string') { report(result); return true; }
    request++; edit = result; composing = false;
    for (const name of ['label', 'destination', 'title'] as const) {
      field(name).value = edit[name]; field(name).disabled = edit.reference;
    }
    apply.disabled = edit.reference; remove.disabled = !edit.existing;
    if (picker) picker.disabled = edit.reference;
    form.querySelector('.link-hint')!.textContent = edit.reference ? `Reference ${kind}: edit its destination in Source mode.` : kind === 'image' ? 'Apply changes source. Choosing a file only fills its path.' : '';
    form.hidden = false; view.requestMeasure();
    (edit.reference ? remove : edit.label ? field('destination') : field('label')).focus();
    return true;
  };
}
