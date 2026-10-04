import { describe, expect, it } from 'vitest';
import commands from '../../src/web/generated/commands.mjs';

describe('generated Bend Return command', () => {
  for (const [source, expected] of [
    ['plain', '\n'], ['- item', '\n- '], ['1. text', '\n2. '],
    ['009) text', '\n010) '], ['9. text', '\n10. '],
    ['- [x] done', '\n- [ ] '], ['- [X] done', '\n- [ ] '],
    ['- [ ] ', ''], ['12. ', ''], ['999999999. item', '\n'],
    ['```\n- item', '\n'], ['日本語😀', '\n'],
    ['first\r\n- item', '\r\n- '],
  ]) it(`plans Return for ${JSON.stringify(source)}`, () => {
    const edit = commands.return_edit(source, source.length, source.length);
    expect(edit.text).toBe(expected);
    const scalarLength = Array.from(source).length;
    expect(Number(edit.end)).toBe(scalarLength);
    expect(Number(edit.start)).toBe(expected ? scalarLength : source.lastIndexOf('\n') + 1);
  });
  it('replaces a selection without continuing its list', () => {
    expect(commands.return_edit('- item', 2, 6)).toEqual({ $: 'ListReturn.Edit', start: 2n, end: 6n, text: '\n' });
  });
});
