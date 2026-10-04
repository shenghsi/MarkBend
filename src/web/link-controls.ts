import { EditorView } from '@codemirror/view';
import { applyLink, LinkEdit, openLink, removeLink } from './links';

export function linkControls(view: EditorView, parent: HTMLElement, report: (message: string) => void) {
  const form = document.createElement('form');
  form.className = 'link-controls'; form.hidden = true; form.setAttribute('aria-label', 'Link controls');
  form.innerHTML = `<label>Text<input name="label" aria-label="Link text"></label><label>Destination<input name="destination" aria-label="Link destination"></label><label>Title (optional)<input name="title" aria-label="Link title"></label><button type="submit">Apply Link</button><button type="button" data-remove>Remove Link</button><button type="button" data-cancel>Cancel</button><span class="link-hint"></span>`;
  parent.after(form);
  const field = (name: string) => form.elements.namedItem(name) as HTMLInputElement;
  const apply = form.querySelector<HTMLButtonElement>('[type="submit"]')!, remove = form.querySelector<HTMLButtonElement>('[data-remove]')!;
  let edit: LinkEdit | undefined, composing = false;
  const close = () => { edit = undefined; form.hidden = true; composing = false; view.requestMeasure(); view.focus(); };
  const commit = (removeOnly = false) => {
    if (!edit) return;
    if (composing) { report('Finish text input, then apply the link command.'); return; }
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
  return () => {
    const result = openLink(view);
    if (typeof result === 'string') { report(result); return true; }
    edit = result; composing = false;
    for (const name of ['label', 'destination', 'title'] as const) {
      field(name).value = edit[name]; field(name).disabled = edit.reference;
    }
    apply.disabled = edit.reference; remove.disabled = !edit.existing;
    form.querySelector('.link-hint')!.textContent = edit.reference ? 'Reference link: edit its destination in Source mode.' : '';
    form.hidden = false; view.requestMeasure();
    (edit.reference ? remove : edit.label ? field('destination') : field('label')).focus();
    return true;
  };
}
