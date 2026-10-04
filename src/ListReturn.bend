import Base
import ./Blocks.bend as Blocks
import ./ScalarText.bend as Scalar
import ./Document.bend as Document

type Edit is Data:
  Edit{start: Nat, end: Nat, text: String}

type Line is Data:
  Line{body: String, ending: String}

type Prefix is Data:
  Prefix{original: String, next: String}

type Spacing is Data:
  Spacing{whitespace: String, rest: String}

def split(line: String, reversed: List<&2, Char>) -> Line:
  match line:
    case SCon{'\r', SCon{'\n', SNil{}}}:
      Line{Scalar.from_reversed(reversed, ""), "\r\n"}
    case SCon{'\n', SNil{}}:
      Line{Scalar.from_reversed(reversed, ""), "\n"}
    case SCon{char, rest}:
      split(rest, char <> reversed)
    case SNil{}:
      Line{Scalar.from_reversed(reversed, ""), ""}

def ending(current: String, previous: String) -> String:
  match current previous:
    case SNil{} SNil{}:
      "\n"
    case SNil{} previous:
      previous
    case current _:
      current

def spaces(text: String, reversed: List<&2, Char>) -> Spacing:
  match text:
    case SCon{' ', rest}:
      spaces(rest, ' ' <> reversed)
    case SCon{'\t', rest}:
      spaces(rest, '\t' <> reversed)
    case text:
      Spacing{Scalar.from_reversed(reversed, ""), text}

def absent() -> Prefix:
  Prefix{"", ""}

def task_spacing(valid: Bool, +base: String, state: Char, +whitespace: String) -> Prefix:
  match valid:
    case True{}:
      Prefix{base ++ SCon{'[', SCon{state, "]"}} ++ whitespace,
        base ++ "[ ]" ++ whitespace}
    case False{}:
      Prefix{base, base}

def task_after(+base: String, state: Char, spacing: Spacing) -> Prefix:
  match spacing:
    case Spacing{+whitespace, rest}:
      task_spacing(Bool.not(String.is_empty(whitespace)) || String.is_empty(rest),
        base, state, whitespace)

def task_checked(valid: Bool, +base: String, state: Char, rest: String) -> Prefix:
  match valid:
    case True{}:
      task_after(base, state, spaces(rest, Nil{}))
    case False{}:
      Prefix{base, base}

def task(+base: String, rest: String) -> Prefix:
  match rest:
    case SCon{'[', SCon{+state, SCon{']', after}}}:
      task_checked(Char.is_eq(state, ' ') || Char.is_eq(state, 'x') || Char.is_eq(state, 'X'),
        base, state, after)
    case _:
      Prefix{base, base}

def bullet(marker: Char, spacing: Spacing) -> Prefix:
  match spacing:
    case Spacing{SNil{}, rest}:
      absent()
    case Spacing{whitespace, rest}:
      task(SCon{marker, whitespace}, rest)

# Preserve leading-zero width. Growth can add a digit to the new marker.
def numbered(width: Nat, +value: U32) -> String:
  match width:
    case 0n:
      match value:
        case 0:
          ""
        case value:
          U32.show(value)
    case 1n+rest:
      numbered(rest, U32.div(value, 10)) ++
        SCon{Char.from_u32(U32.add(48, U32.mod(value, 10))), ""}

def ordered_spacing(valid: Bool, reversed: List<&2, Char>, width: Nat,
  value: U32, +delimiter: Char, spacing: Spacing) -> Prefix:
  match valid spacing:
    case True{} Spacing{+whitespace, rest}:
      match whitespace:
        case SNil{}:
          absent()
        case +whitespace:
          Prefix{Scalar.from_reversed(reversed, SCon{delimiter, whitespace}),
            numbered(width, U32.add(value, 1)) ++ SCon{delimiter, whitespace}}
    case False{} _:
      absent()

def ordered_step(digit: Bool, +char: Char, rest: String, +width: Nat,
  +value: U32, reversed: List<&2, Char>, next: Unit -> Prefix) -> Prefix:
  match digit:
    case True{}:
      match width:
        case 9n:
          absent()
        case _:
          next(Unit{})
    case False{}:
      ordered_spacing(Nat.is_ge(width, 1n) && U32.is_lt(value, 999999999) &&
        (Char.is_eq(char, '.') || Char.is_eq(char, ')')),
        reversed, width, value, char, spaces(rest, Nil{}))

def ordered_scan(text: String, +width: Nat, +value: U32, +reversed: List<&2, Char>) -> Prefix:
  match text:
    case SNil{}:
      absent()
    case SCon{+char, +rest}:
      ordered_step(Char.is_digit(char), char, rest, width, value, reversed,
        _ => ordered_scan(rest, Nat.add(width, 1n),
          U32.add(U32.mul(value, 10), U32.sub(Char.to_u32(char), 48)),
          char <> reversed))

def prefix(body: String) -> Prefix:
  match body:
    case SCon{'-', rest}:
      bullet('-', spaces(rest, Nil{}))
    case SCon{'*', rest}:
      bullet('*', spaces(rest, Nil{}))
    case SCon{'+', rest}:
      bullet('+', spaces(rest, Nil{}))
    case body:
      ordered_scan(body, 0n, 0, Nil{})

def protected(mode: Blocks.Mode, kind: Blocks.BlockKind) -> Bool:
  match mode kind:
    case Blocks.FenceOpen{marker, width, lines} _:
      True{}
    case _ Blocks.Fence{marker, width, closed}:
      True{}
    case _ _:
      False{}

def item_kind(empty: Bool, prefix: String, offset: Nat, +position: Nat, newline: String) -> Edit:
  match empty:
    case True{}:
      Edit{offset, position, ""}
    case False{}:
      Edit{position, position, newline ++ prefix}

def item(prefix: Prefix, body: String, offset: Nat, +position: Nat, newline: String) -> Edit:
  match prefix:
    case Prefix{SNil{}, next}:
      Edit{position, position, newline}
    case Prefix{original, next}:
      item_kind(Nat.is_eq(Document.count_scalars(original, 0n), Document.count_scalars(body, 0n)),
        next, offset, position, newline)

def choose(continue: Bool, +body: String, offset: Nat, +start: Nat, end: Nat,
  newline: String) -> Edit:
  match continue:
    case True{}:
      item(prefix(body), body, offset, start, newline)
    case False{}:
      Edit{start, end, newline}

def line_edit(line: Line, +offset: Nat, +start: Nat, +end: Nat, previous: String,
  forbidden: Bool) -> Edit:
  match line:
    case Line{+body, current}:
      choose(Nat.is_eq(start, end) && Nat.is_eq(start, Nat.add(offset, Document.count_scalars(body, 0n))) &&
        Bool.not(forbidden), body, offset, start, end, ending(current, previous))

def next_mode(step: Blocks.Step) -> Blocks.Mode:
  match step:
    case Blocks.Step{mode, emitted}:
      mode

def located(here: Bool, +parts: Line, +line: String,
  offset: Nat, +start: Nat, +end: Nat, +previous: String,
  +mode: Blocks.Mode, +kind: Blocks.BlockKind, rest: Blocks.Mode -> String -> Edit) -> Edit:
  match here parts:
    case True{} _:
      line_edit(parts, offset, start, end, previous, protected(mode, kind))
    case False{} Line{body, current}:
      rest(next_mode(Blocks.step(mode, kind, line)), ending(current, previous))

def locate(+parts: Line, +line: String, offset: Nat, +boundary: Nat,
  +start: Nat, +end: Nat, previous: String, mode: Blocks.Mode,
  rest: Blocks.Mode -> String -> Edit) -> Edit:
  match parts:
    case Line{body, +current}:
      located(Nat.is_lt(start, boundary) || (String.is_empty(current) && Nat.is_eq(start, boundary)),
        parts, line, offset, start, end, previous, mode, Blocks.classify(line), rest)

def scan(lines: List<&2, String>, +offset: Nat, +start: Nat, +end: Nat,
  +previous: String, +mode: Blocks.Mode) -> Edit:
  match lines:
    case Nil{}:
      line_edit(Line{"", ""}, offset, start, end, previous, protected(mode, Blocks.Blank{}))
    case +line <> rest:
      +boundary = Nat.add(offset, Document.count_scalars(line, 0n))
      locate(split(line, Nil{}), line, offset, boundary, start, end, previous, mode,
        next => newline => scan(rest, boundary, start, end, newline, next))

def plan(source: String, +start: Nat, +end: Nat) -> Edit:
  scan(Blocks.lines(source), 0n, Nat.min(start, end), Nat.max(start, end), "", Blocks.Idle{})
