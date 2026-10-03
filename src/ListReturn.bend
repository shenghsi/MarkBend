import Base
import ./Blocks.bend as Blocks
import ./ScalarText.bend as Scalar
import ./Document.bend as Document

type Edit is Data:
  Edit{start: Nat, end: Nat, text: String}

type Line is Data:
  Line{body: String, ending: String}

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

def spaces(text: String, reversed: List<&2, Char>) -> String:
  match text:
    case SCon{' ', rest}:
      spaces(rest, ' ' <> reversed)
    case SCon{'\t', rest}:
      spaces(rest, '\t' <> reversed)
    case _:
      Scalar.from_reversed(reversed, "")

def spaced(marker: Char, whitespace: String) -> String:
  match whitespace:
    case SNil{}:
      ""
    case whitespace:
      SCon{marker, whitespace}

def marked(valid: Bool, marker: Char, rest: String) -> String:
  match valid:
    case True{}:
      spaced(marker, spaces(rest, Nil{}))
    case False{}:
      ""

def prefix(body: String) -> String:
  match body:
    case SCon{+marker, rest}:
      marked(Char.is_eq(marker, '-') || Char.is_eq(marker, '*') || Char.is_eq(marker, '+'), marker, rest)
    case SNil{}:
      ""

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

def item(+prefix: String, body: String, offset: Nat, +position: Nat, newline: String) -> Edit:
  match prefix:
    case SNil{}:
      Edit{position, position, newline}
    case _:
      item_kind(Nat.is_eq(Document.count_scalars(prefix, 0n), Document.count_scalars(body, 0n)),
        prefix, offset, position, newline)

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
