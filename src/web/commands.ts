import commands from './generated/commands.mjs';
import { EditorView } from '@codemirror/view';
import { normalize, rawOffset, restoreSource, sourceField, viewOffset } from './source';

export function bendReturn(view: EditorView): boolean {
  if (view.compositionStarted || view.state.readOnly || view.state.selection.ranges.length !== 1) return false;
  const record = view.state.field(sourceField), selection = view.state.selection.main;
  const edit = commands.return_edit(record.raw, rawOffset(record.raw, selection.from), rawOffset(record.raw, selection.to));
  const scalarOffset = (position: bigint) => Array.from(record.raw).slice(0, Number(position)).join('').length;
  const start = scalarOffset(edit.start), end = scalarOffset(edit.end);
  const raw = record.raw.slice(0, start) + edit.text + record.raw.slice(end);
  view.dispatch({ changes: { from: viewOffset(record.raw, start), to: viewOffset(record.raw, end), insert: normalize(edit.text) },
    selection: { anchor: viewOffset(raw, start + edit.text.length) },
    effects: restoreSource.of({ ...record, raw }), userEvent: 'input' });
  return true;
}
