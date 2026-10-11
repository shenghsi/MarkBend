// @vitest-environment jsdom
import { expect, it, vi } from 'vitest';
import { EditorState, RangeSet } from '@codemirror/state';
import { Decoration, DecorationSet } from '@codemirror/view';
import { ensureSyntaxTree, syntaxTree } from '@codemirror/language';
import { documentLanguage } from '../../src/web/document-language';
import { livePreview, previewField } from '../../src/web/preview';
import { fromSource, normalize, savedSource, sourceExtensions, sourceField } from '../../src/web/source';

// Inactive diagnosis. This file changes no app decorations or package methods.
function inventory(state: EditorState, set: DecorationSet) {
  const counts: Record<string, { ranges: number; units: number; maxUnits: number }> = {};
  const hiddenSource: Record<string, number> = {};
  for (const cursor = set.iter(); cursor.value; cursor.next()) {
    const value = cursor.value, size = cursor.to - cursor.from;
    const widget = value.spec.widget;
    const kind = !value.point ? 'non-point' : widget
      ? `widget:${widget.item?.kind ?? (widget.marker ? 'marker' : widget.constructor.name)}`
      : size === 0 ? (value.spec.attributes ? 'line-decoration' : 'empty-point') : state.doc.lineAt(cursor.from).number === state.doc.lineAt(cursor.to).number
        ? 'empty-replacement:same-line' : 'empty-replacement:multiline';
    const count = counts[kind] ??= { ranges: 0, units: 0, maxUnits: 0 };
    count.ranges++; count.units += size; count.maxUnits = Math.max(count.maxUnits, size);
    if (kind.startsWith('empty-replacement')) {
      const text = state.sliceDoc(cursor.from, cursor.to);
      const label = text.length <= 32 ? text : `${text.slice(0, 32)}…`;
      hiddenSource[label] = (hiddenSource[label] ?? 0) + 1;
    }
  }
  return { counts, hiddenSource };
}

it.skipIf(process.env.MARKBEND_POINT_INVENTORY !== '1')('reports static preview point ranges and height comparison changes', () => {
  const header = '\uFEFF# Input observation\r\n\r\nParagraph words 日本語 and **strong text**[^a].\r\n\r\n';
  const block = '# Heading\n\nParagraph with **strong text**, `code`, and words.\n\n';
  const tail = '\r\n[^a]: 日本語 note\r\n';
  const encoder = new TextEncoder(), remaining = 1048576 - encoder.encode(header + tail).length;
  const original = header + block.repeat(Math.floor(remaining / block.length)) + 'w'.repeat(remaining % block.length) + tail;
  const resource = '# Heading\n\nParagraph **bold** and *two\nlines*, `code`, $x$, and ![alt](image.png).\n\n'
    + '- item\n- [ ] task\n\n> quote\n\n---\n\n| A | B |\n| - | - |\n| x | y |\n\n'
    + '```mermaid\nflowchart LR\nA-->B\n```\n\n<div>HTML</div>\n\nReference[^a].\n\n[^a]: Note.\n';
  for (const [name, source] of [['input-note-1MiB', original], ['resource-types', resource]]) {
    const record = fromSource(source), doc = normalize(record.raw), anchor = doc.indexOf('Paragraph') + 3;
    let state = EditorState.create({ doc, selection: { anchor }, extensions: [
      sourceExtensions(record), documentLanguage(), livePreview,
    ] });
    expect(ensureSyntaxTree(state, state.doc.length, 10000)).not.toBeNull();
    state = state.update({}).state;
    expect(syntaxTree(state).length).toBe(state.doc.length);
    const before = state.field(previewField).decorations;
    // This is a settled-state inventory, not a real-input parser clock.
    const clock = vi.spyOn(Date, 'now').mockReturnValue(Date.now());
    let transaction;
    try { transaction = state.update({ changes: { from: anchor, insert: 'x' }, selection: { anchor: anchor + 1 } });
      state = transaction.state;
    } finally { clock.mockRestore(); }
    expect(syntaxTree(state).length).toBe(state.doc.length);
    const after = state.field(previewField).decorations;
    const changed: Record<string, number> = {};
    let rangeChanges = 0;
    const category = (value: Decoration | null) => !value ? 'absent' : value.spec.widget
      ? `widget:${value.spec.widget.item?.kind ?? value.spec.widget.constructor.name}` : 'empty-replacement';
    RangeSet.compare([before], [after], transaction.changes, {
      compareRange() { rangeChanges++; },
      comparePoint(_from, _to, left, right) {
        const key = `${category(left)} -> ${category(right)}`;
        changed[key] = (changed[key] ?? 0) + 1;
      },
    }, 0);
    const offset = source.indexOf('Paragraph') + 3;
    expect(savedSource(state.field(sourceField))).toBe(source.slice(0, offset) + 'x' + source.slice(offset));
    console.log(JSON.stringify({ diagnostic: 'preview-point-inventory', name, bytes: encoder.encode(source).length,
      node: process.version, platform: process.platform, arch: process.arch, complete: true,
      mode: state.field(previewField).mode, before: inventory(transaction.startState, before),
      after: inventory(state, after), heightComparatorNotifications: changed, rangeChanges,
      scope: 'static preview ranges only; callback counts identify differences, not equal ranges visited; no DOM, viewport, input or timing claim' }));
  }
}, 30000);
