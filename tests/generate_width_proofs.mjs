// Generate proof-only partitions for 32-bit words, least significant bit first.
// Constants: asterisk 42, backtick 96, backslash 92.
// A missing target prefix retains every possible unexamined suffix.
import { readFileSync } from 'node:fs';

const headers = {
  "long": "import Base\nimport ./Projection.bend as P\nimport ./CursorMap.bend as C\n\ndef width(chunk: C.Chunk) -> P.Width:\n  match chunk:\n    case C.Chunk{positions, remaining, offset}:\n      P.Width{remaining, offset}\n\nlaw loop:\n  for +visible: List<&2, Char>\n  for +chars: List<&2, Char>\n  for +offset: Nat\n  for reversed: List<&2, Nat>\n  for +plain: Bool\n  {P.consume_width(visible, chars, offset, plain) == width(C.consume_loop(visible, chars, offset, plain, reversed)) : P.Width}\n\n",
  "short": "import Base\nimport ./Projection.bend as P\nimport ./CursorMap.bend as C\nimport ./ProjectionWidthLongProof.bend as Long\n\nlaw prepend_width:\n  for position: Nat\n  for +chunk: C.Chunk\n  {Long.width(C.prepend(position, chunk)) == Long.width(chunk) : P.Width}\n\ndef prepend_width(position, chunk):\n  match chunk:\n    case C.Chunk{positions, remaining, offset}:\n      {==}\n\nlaw step:\n  for +visible: List<&2, Char>\n  for +chars: List<&2, Char>\n  for +offset: Nat\n  for +plain: Bool\n  for +position: Nat\n  for hypothesis: {P.consume_width(visible, chars, offset, plain) == Long.width(C.consume_short(visible, chars, offset, plain)) : P.Width}\n  {P.consume_width(visible, chars, offset, plain) == Long.width(C.prepend(position, C.consume_short(visible, chars, offset, plain))) : P.Width}\n\ndef step(visible, chars, offset, plain, position, hypothesis):\n  Equal.trans(P.Width,\n    P.consume_width(visible, chars, offset, plain),\n    Long.width(C.consume_short(visible, chars, offset, plain)),\n    Long.width(C.prepend(position, C.consume_short(visible, chars, offset, plain))),\n    hypothesis,\n    Equal.sym(P.Width,\n      Long.width(C.prepend(position, C.consume_short(visible, chars, offset, plain))),\n      Long.width(C.consume_short(visible, chars, offset, plain)),\n      prepend_width(position, C.consume_short(visible, chars, offset, plain))))\n\nlaw loop:\n  for +visible: List<&2, Char>\n  for +chars: List<&2, Char>\n  for +offset: Nat\n  for +plain: Bool\n  {P.consume_width(visible, chars, offset, plain) == Long.width(C.consume_short(visible, chars, offset, plain)) : P.Width}\n\n"
};
function word(bits, suffix) {
  return bits.reduceRight((s, b) => `WCon{${b ? 'True' : 'False'}{}, ${s}}`, suffix);
}
function leaves(values, prefix = []) {
  if (prefix.length === 32) return [{ bits: prefix, value: values[0], suffix: 'WNil{}' }];
  const result = [];
  for (const bit of [0, 1]) {
    const next = values.filter(value => ((value >>> prefix.length) & 1) === bit);
    if (next.length) result.push(...leaves(next, [...prefix, bit]));
    else result.push({ bits: [...prefix, bit], value: null, suffix: 'suffix' });
  }
  return result;
}
function generate(kind) {
  const short = kind === 'short';
  const call = (rest, escape = false, plain = 'plain') => {
    const next = escape ? '2n+offset' : '1n+offset';
    const position = escape ? '1n+offset' : 'offset';
    if (short) return `step(tail, ${rest}, ${next}, ${plain}, ${position}, loop(tail, ${rest}, ${next}, ${plain}))`;
    const reversed = escape ? 'Con{1n+offset, reversed}' : 'offset <> reversed';
    return `loop(tail, ${rest}, ${next}, ${reversed}, ${plain})`;
  };
  let output = headers[kind] + `def loop(visible, chars, offset, ${short ? '' : 'reversed, '}plain):
  match visible:
    case Nil{}:
      {==}
    case Chr{U32{visible_word}} <> tail:
      match visible_word:
`;
  for (const visible of leaves([42, 96])) {
    output += `        case ${word(visible.bits, visible.suffix)}:
          match chars:
            case Nil{}:
              {==}
`;
    if (visible.value === null) {
      output += `            case char <> rest:
              ${call('rest')}
`;
      continue;
    }
    output += `            case Chr{U32{source_word}} <> rest:
              match source_word:
`;
    for (const source of leaves([92])) {
      output += `                case ${word(source.bits, source.suffix)}:
`;
      if (source.value === null) {
        output += `                  ${call('rest')}
`;
        continue;
      }
      output += `                  match rest:
                    case Nil{}:
                      ${call('Nil{}')}
                    case Chr{U32{second_word}} <> last:
                      match second_word:
`;
      for (const second of leaves([visible.value])) {
        output += `                        case ${word(second.bits, second.suffix)}:
`;
        const rest = `Chr{U32{${word(second.bits, second.suffix)}}} <> last`;
        if (second.value === null) output += `                          ${call(rest)}
`;
        else output += `                          match plain:
                            case False{}:
                              ${call(rest, false, 'False{}')}
                            case True{}:
                              ${call('last', true, 'True{}')}
`;
      }
    }
  }
  return output;
}
const files = { long: 'ProjectionWidthLongProof.bend', short: 'ProjectionWidthShortProof.bend' };
if (process.argv[2] === '--print' && files[process.argv[3]]) {
  process.stdout.write(generate(process.argv[3]));
} else if (process.argv[2] === '--check') {
  for (const [kind, filename] of Object.entries(files)) {
    const actual = readFileSync(new URL('../src/' + filename, import.meta.url), 'utf8');
    if (actual !== generate(kind)) throw new Error('Generated proof differs: ' + filename);
  }
  console.log('Width proof generation checks passed.');
} else {
  throw new Error('Use --check or --print long|short.');
}
