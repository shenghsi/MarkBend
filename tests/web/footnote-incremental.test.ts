// @vitest-environment jsdom
import { expect, it } from 'vitest';
import { EditorState, Transaction } from '@codemirror/state';
import { history, undo, redo } from '@codemirror/commands';
import { documentLanguage } from '../../src/web/document-language';
import { footnoteField, footnotes, freshFootnotes, renderFootnote } from '../../src/web/footnotes';
import { fromSource, normalize, savedSource, sourceExtensions, sourceField } from '../../src/web/source';

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

it('does not reuse text ranges when a word edit creates an ordered-list marker', () => {
  for (const line of ['1a1. text', '  1a1) text', '> 1a1. text', '- Parent\n  1a1. text']) {
    const original = line + '\n\nwords[^n]\n\n[^n]: Note';
    let state = create(original), from = original.indexOf('a1');
    state = state.update({ changes: { from, to: from + 1, insert: '' } }).state; check(state);
  }
});

it.each([
  ['&axp; words[^n]', 'x', 'm'],
  ['&amp; words[^n]', 'm', 'x'],
  ['[abc] words[^n]\n\n[abc]: https://example.com', 'b', 'Z'],
  ['[abc][] words[^n]\n\n[abc]: https://example.com', 'b', 'Z'],
  ['[abc][ref] words[^n]\n\n[ref]: https://example.com', 'b', 'ZZ'],
  ['[abc[^n]](https://example.com) words[^n]', 'b', 'ZZ'],
])('matches fresh parsing for protected entity/link text: %s', (body, old, replacement) => {
    const original = body + '\n\n[^n]: Note';
    let state = create(original), from = original.indexOf(old);
    state = state.update({ changes: { from, to: from + 1, insert: replacement } }).state; check(state);
});

it.each(['中文写作文本', '日本語かなカナ', '한글문장입력', '𠀀𠀁𠀂', 'a\u0301bc', 'אבגדה', 'العربية'])
  ('reuses complete word edits and matches fresh UTF-16 ranges for %s', word => {
    const original = '---\na: b\n---\n\nA' + word + 'Z words[^n]\n\n[^n]: Note **text** $x$';
    const initial = create(original), from = original.indexOf(word);
    const changed = initial.update({ changes: { from, to: from + word.length, insert: Array.from(word).reverse().join('') } }).state;
    check(changed);
    expect(footnotes(changed)).toBe(footnotes(initial));
    for (const insert of [word, word + '中', '', 'Z', 'e\u0301']) {
      const state = initial.update({ changes: { from, to: from + word.length, insert } }).state; check(state);
      if (insert.length === word.length) expect(footnotes(state)).toBe(footnotes(initial));
    }
  });

it('keeps complete neighbouring supplementary characters and rejects edits that split them', () => {
  const original = '𠀀abc𠀁 words[^n]\n\n[^n]: Note';
  let state = create(original);
  state = state.update({ changes: { from: 2, to: 5, insert: '中文' } }).state; check(state);
  state = create(original).update({ changes: [{ from: 3, to: 4, insert: '中' }, { from: 1, insert: 'Z' }] }).state; check(state);
  for (const [from, to] of [[0, 1], [1, 2], [5, 6], [6, 7]]) {
    state = create(original).update({ changes: { from, to, insert: '中' } }).state; check(state);
  }
});

it('matches fresh parsing beside delimiters, across multiple Unicode changes and digit guards', () => {
  const original = '**A中文Z** and *e\u0301中文a* words[^n]\n\n[^n]: Note';
  const from = original.indexOf('中文');
  for (const insert of ['文', '𠀀', '\u0301', ' ', '$', '[^n]', '\n', '😀']) {
    const state = create(original).update({ changes: { from, to: from + 2, insert } }).state; check(state);
  }
  let state = create(original).update({ changes: [{ from, to: from + 1, insert: '한글' },
    { from: original.lastIndexOf('中文'), to: original.lastIndexOf('中文') + 1, insert: 'か' }] }).state; check(state);
  for (const line of ['1中文1. text', '> 1中文1) text', '- Parent\n  1中文1. text']) {
    const source = line + '\n\nwords[^n]\n\n[^n]: Note', from = source.indexOf('中文');
    state = create(source).update({ changes: [{ from, to: from + 1, insert: '' }, { from: from + 1, to: from + 2, insert: '' }] }).state; check(state);
  }
});

it('retains exact source history for composition-labelled Unicode replacements', () => {
  const original = '\uFEFFA中文Z words[^n]\r\n\r\n[^n]: Note **text** $x$\nTail\rEnd', record = fromSource(original);
  let state = EditorState.create({ doc: normalize(record.raw), extensions: [
    documentLanguage(), footnoteField, history(), sourceExtensions(record)
  ] });
  const target = { get state() { return state; }, dispatch(transaction: Transaction) { state = transaction.state; } };
  state = state.update({ changes: { from: 1, to: 3, insert: '日本語' }, userEvent: 'input.type.compose.start' }).state; check(state);
  const first = original.replace('中文', '日本語'); expect(savedSource(state.field(sourceField))).toBe(first);
  state = state.update({ changes: { from: 1, to: 4, insert: '𠀀' }, userEvent: 'input.type.compose' }).state; check(state);
  const second = original.replace('中文', '𠀀'); expect(savedSource(state.field(sourceField))).toBe(second);
  expect(undo(target)).toBe(true); check(state); expect(savedSource(state.field(sourceField))).toBe(original);
  expect(redo(target)).toBe(true); check(state); expect(savedSource(state.field(sourceField))).toBe(second);
  state = state.update({ changes: { from: 1, to: 3, insert: '한글' }, userEvent: 'input.type.compose.start' }).state; check(state);
  const third = original.replace('中文', '한글'); expect(savedSource(state.field(sourceField))).toBe(third);
  expect(undo(target)).toBe(true); check(state); expect(savedSource(state.field(sourceField))).toBe(second);
  expect(undo(target)).toBe(true); check(state); expect(savedSource(state.field(sourceField))).toBe(original);
  expect(redo(target)).toBe(true); check(state); expect(savedSource(state.field(sourceField))).toBe(second);
  expect(redo(target)).toBe(true); check(state); expect(savedSource(state.field(sourceField))).toBe(third);
});
