import { EditorState, StateEffect, StateField } from '@codemirror/state';
import { invertedEffects, isolateHistory } from '@codemirror/commands';

export interface SourceRecord { raw: string; bom: boolean }
export const normalize = (text: string) => text.replace(/\r\n|\r/g, '\n');
export function fromSource(source: string): SourceRecord {
  const bom = source.startsWith('\uFEFF');
  return { bom, raw: bom ? source.slice(1) : source };
}
export const savedSource = (record: SourceRecord) => (record.bom ? '\uFEFF' : '') + record.raw;

export function rawOffset(raw: string, position: number): number {
  let logical = 0, offset = 0;
  while (offset < raw.length && logical < position) {
    offset += raw[offset] === '\r' && raw[offset + 1] === '\n' ? 2 : 1;
    logical++;
  }
  return offset;
}
export const viewOffset = (raw: string, position: number) => normalize(raw.slice(0, position)).length;
export const lineEnding = (raw: string) => /\r\n|\r|\n/.exec(raw)?.[0] || '\n';

export const restoreSource = StateEffect.define<SourceRecord>();
export const sourceField = StateField.define<SourceRecord>({
  create: state => ({ raw: state.doc.toString(), bom: false }),
  update(record, transaction) {
    const restores = transaction.effects.filter(effect => effect.is(restoreSource));
    if (restores.length) return restores[restores.length - 1].value;
    if (!transaction.docChanged) return record;
    const edits: { from: number; to: number; text: string }[] = [];
    transaction.changes.iterChanges((from, to, _a, _b, inserted) => {
      edits.push({ from: rawOffset(record.raw, from), to: rawOffset(record.raw, to),
        text: inserted.toString().replace(/\n/g, lineEnding(record.raw)) });
    });
    let raw = record.raw;
    for (const edit of edits.reverse()) raw = raw.slice(0, edit.from) + edit.text + raw.slice(edit.to);
    return { ...record, raw };
  },
});

export function sourceExtensions(record: SourceRecord) {
  return [sourceField.init(() => record), EditorState.lineSeparator.of('\n'),
    invertedEffects.of(transaction => transaction.docChanged
      ? [restoreSource.of(transaction.startState.field(sourceField))] : []),
    EditorState.transactionExtender.of(transaction => transaction.docChanged
      ? { annotations: isolateHistory.of('full') } : null)];
}
