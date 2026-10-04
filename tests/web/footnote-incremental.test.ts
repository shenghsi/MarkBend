// @vitest-environment jsdom
import { expect, it } from 'vitest';
import { EditorState } from '@codemirror/state';
import { documentLanguage } from '../../src/web/document-language';
import { footnoteField, footnotes, freshFootnotes, renderFootnote } from '../../src/web/footnotes';

function create(doc: string) { return EditorState.create({ doc, extensions: [documentLanguage(), footnoteField] }); }
function check(state: EditorState) {
  const cached = footnotes(state), fresh = freshFootnotes(state);
  expect(cached).toEqual(fresh);
  expect(cached.definitions.map(renderFootnote)).toEqual(fresh.definitions.map(renderFootnote));
}
it('matches fresh parsing after plain text edits with shifted definition AST and UTF-16 ranges', () => {
  let state = create('---\na: b\n---\n\n😀 Ordinary words[^n] and more words.\n\n[^n]: Note **text** $x$\n\nTail words');
  const from = state.doc.toString().indexOf('Ordinary') + 2;
  for (const insert of ['Z', 'QQ', '', 'ABC', '9']) {
    state = state.update({ changes: { from, to: from + 1, insert } }).state; check(state);
  }
});
it('matches fresh parsing after multiple changes and fallback structural reference and definition edits', () => {
  const original = 'First words[^a] and other words[^b].\n\n[^a]: Alpha\n\n[^b]: Beta\n\nLast words';
  for (const insert of ['Z', 'ZZ', '', '\n', '[^b]', '$', '<div>', '`', '\\', '**', '    ']) {
    let state = create(original);
    state = state.update({ changes: [{ from: 2, to: 3, insert }, { from: original.indexOf('other') + 2, to: original.indexOf('other') + 3, insert: 'Q' }] }).state; check(state);
  }
  for (const target of ['[^a]', '[^a]:', 'Alpha', 'Beta']) {
    let state = create(original), from = original.indexOf(target);
    state = state.update({ changes: { from, to: from + target.length, insert: 'replacement' } }).state; check(state);
  }
});
it('does not reuse a multiline text range when an interior line becomes blank', () => {
  const original = 'First words\nABC\n[^n]: could become a definition\nlast words[^n]\n\nEnd';
  let state = create(original), from = original.indexOf('ABC');
  state = state.update({ changes: { from, to: from + 3, insert: '' } }).state; check(state);
  state = create('First words\nABCDEF\nlast words[^n]\n\n[^n]: Note\n\nEnd'); from = state.doc.toString().indexOf('ABCDEF');
  state = state.update({ changes: [{ from, to: from + 3, insert: '' }, { from: from + 3, to: from + 6, insert: '' }] }).state; check(state);
});
it('matches fresh context when changes alter metadata code math HTML or missing labels', () => {
  for (const [original, target] of [
    ['---\na: b\n---\n\nwords[^n]\n\n[^n]: Note', 'a: b'],
    ['```text\nwords[^n]\n```\n\n[^n]: Note', 'text'],
    ['$words[^n]$\n\n[^n]: Note', 'words'],
    ['<div>\nwords[^n]\n</div>\n\n[^n]: Note', 'div'],
    ['words[^missing]\n\n[^n]: Note', 'missing'],
  ]) {
    let state = create(original), from = original.indexOf(target);
    state = state.update({ changes: { from, to: from + target.length, insert: 'n' } }).state; check(state);
  }
});
it('falls back for ordered-list creation delimiter-adjacent deletion and deleted word-edge guards', () => {
  for (const [original, changes] of [
    ['First words\nx) text\nlast words[^n]\n\n[^n]: Note', [{ from: 12, to: 13, insert: '1' }]],
    ['First words\nabc* text\nlast words[^n]\n\n[^n]: Note', [{ from: 14, to: 15, insert: '' }]],
    ['😀 ABCDEF words[^n]\n\n[^n]: Note', [{ from: 3, to: 6, insert: '' }, { from: 6, to: 9, insert: '' }]],
    ['😀 ABCDEF words[^n]\n\n[^n]: Note', [{ from: 4, to: 6, insert: '' }, { from: 6, to: 8, insert: '' }]],
  ] as const) {
    let state = create(original);
    state = state.update({ changes: [...changes] }).state; check(state);
  }
});
