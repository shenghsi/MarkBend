import Base

# Every piece retains its exact source, including line endings and fence marks.
# This is a block parser for the document experiment, not full CommonMark.
type BlockKind is Data:
  Paragraph{}
  Blank{}
  Heading{level: Nat}
  ListItem{ordered: Bool}
  Quote{}
  Fence{marker: Char, width: Nat, closed: Bool}

type Piece is Data:
  Piece{kind: BlockKind, source: String}

type Mode is Data:
  Idle{}
  ParagraphOpen{reversed: List<&2, String>}
  FenceOpen{marker: Char, width: Nat, reversed: List<&2, String>}

type Step is Data:
  Step{mode: Mode, emitted: List<&2, Piece>}

def line_text(chars: List<&2, Char>, acc: String) -> String:
  match chars:
    case Nil{}:
      acc
    case char <> rest:
      line_text(rest, SCon{char, acc})

def finish_lines(chars: List<&2, Char>, lines: List<&2, String>) -> List<&2, String>:
  match chars:
    case Nil{}:
      List.reverse(&2, String, lines)
    case _ <> _:
      List.reverse(&2, String,
        line_text(chars, "") <> lines)

def line_scan(source: String, chars: List<&2, Char>, lines: List<&2, String>) -> List<&2, String>:
  match source:
    case SNil{}:
      finish_lines(chars, lines)
    case SCon{'\n', rest}:
      line_scan(rest, Nil{},
        line_text('\n' <> chars, "") <> lines)
    case SCon{char, rest}:
      line_scan(rest, char <> chars, lines)

def lines(source: String) -> List<&2, String>:
  line_scan(source, Nil{}, Nil{})

def strip_indent(fuel: Nat, text: String) -> String:
  match fuel text:
    case 1n+rest SCon{' ', tail}:
      strip_indent(rest, tail)
    case _ _:
      text

def same_count(same: Bool, later: Unit -> Nat) -> Nat:
  match same:
    case True{}:
      1n+later(Unit{})
    case False{}:
      0n

def prefix(text: String, +mark: Char) -> Nat:
  match text:
    case SNil{}:
      0n
    case SCon{char, rest}:
      same_count(Char.is_eq(char, mark), _ => prefix(rest, mark))

def space_or_end(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{' ', _}:
      True{}
    case SCon{'\t', _}:
      True{}
    case SCon{'\n', _}:
      True{}
    case SCon{'\r', _}:
      True{}
    case _:
      False{}

def choose_kind(valid: Bool, kind: BlockKind) -> BlockKind:
  match valid:
    case True{}:
      kind
    case False{}:
      Paragraph{}

def heading(+line: String) -> BlockKind:
  +width = prefix(line, '#')
  choose_kind(Nat.is_le(width, 6n) && space_or_end(String.drop(line, width)), Heading{width})

def fence_start(+line: String, +marker: Char) -> BlockKind:
  +width = prefix(line, marker)
  choose_kind(Nat.is_ge(width, 3n), Fence{marker, width, False{}})

def ordered_tail(text: String) -> Bool:
  match text:
    case SCon{'.', rest}:
      space_or_end(rest)
    case SCon{')', rest}:
      space_or_end(rest)
    case _:
      False{}

def digits(text: String) -> Nat:
  match text:
    case SNil{}:
      0n
    case SCon{char, rest}:
      same_count(Char.is_digit(char), _ => digits(rest))

def ordered(+line: String) -> BlockKind:
  +width = digits(line)
  choose_kind(Nat.is_ge(width, 1n) && Nat.is_le(width, 9n) &&
    ordered_tail(String.drop(line, width)), ListItem{True{}})

def classify_trimmed(+line: String) -> BlockKind:
  match line:
    case SCon{'#', _}:
      heading(line)
    case SCon{'`', _}:
      fence_start(line, '`')
    case SCon{'~', _}:
      fence_start(line, '~')
    case SCon{'>', _}:
      Quote{}
    case SCon{'-', rest}:
      choose_kind(space_or_end(rest), ListItem{False{}})
    case SCon{'+', rest}:
      choose_kind(space_or_end(rest), ListItem{False{}})
    case SCon{'*', rest}:
      choose_kind(space_or_end(rest), ListItem{False{}})
    case _:
      ordered(line)

def classify_blank(blank: Bool, line: String) -> BlockKind:
  match blank:
    case True{}:
      Blank{}
    case False{}:
      classify_trimmed(strip_indent(3n, line))

def classify(+line: String) -> BlockKind:
  classify_blank(String.is_empty(String.trim(line)), line)

def start_step(kind: BlockKind, line: String) -> Step:
  match kind:
    case Paragraph{}:
      Step{ParagraphOpen{[line]}, Nil{}}
    case Fence{marker, width, closed}:
      Step{FenceOpen{marker, width, [line]}, Nil{}}
    case kind:
      Step{Idle{}, [Piece{kind, line}]}

def close_step(closed: Bool, marker: Char, width: Nat, text: List<&2, String>) -> Step:
  match closed:
    case True{}:
      Step{Idle{}, [Piece{Fence{marker, width, True{}}, String.concat(List.reverse(&2, String, text))}]}
    case False{}:
      Step{FenceOpen{marker, width, text}, Nil{}}

def fence_closes(+line: String, +marker: Char, width: Nat) -> Bool:
  +trimmed = strip_indent(3n, line)
  +count = prefix(trimmed, marker)
  Nat.is_ge(count, width) && String.is_empty(String.trim(String.drop(trimmed, count)))

def prepend_step(piece: Piece, step: Step) -> Step:
  match step:
    case Step{mode, emitted}:
      Step{mode, piece <> emitted}

def step(mode: Mode, kind: BlockKind, +line: String) -> Step:
  match mode kind:
    case Idle{} kind:
      start_step(kind, line)
    case ParagraphOpen{text} Paragraph{}:
      Step{ParagraphOpen{line <> text}, Nil{}}
    case ParagraphOpen{text} kind:
      prepend_step(Piece{Paragraph{}, String.concat(List.reverse(&2, String, text))}, start_step(kind, line))
    case FenceOpen{+marker, +width, text} _:
      close_step(fence_closes(line, marker, width), marker, width, line <> text)

def finish(mode: Mode) -> List<&2, Piece>:
  match mode:
    case Idle{}:
      Nil{}
    case ParagraphOpen{text}:
      [Piece{Paragraph{}, String.concat(List.reverse(&2, String, text))}]
    case FenceOpen{marker, width, text}:
      [Piece{Fence{marker, width, False{}}, String.concat(List.reverse(&2, String, text))}]

def stream_step(step: Step, reversed: List<&2, Piece>, rest: Mode -> List<&2, Piece> -> Step) -> Step:
  match step:
    case Step{mode, emitted}:
      rest(mode, List.reverse.go(&2, Piece, emitted, reversed))

def stream(lines: List<&2, String>, mode: Mode, reversed: List<&2, Piece>) -> Step:
  match lines:
    case Nil{}:
      Step{mode, List.reverse(&2, Piece, reversed)}
    case +line <> rest:
      stream_step(step(mode, classify(line), line), reversed,
        next => saved => stream(rest, next, saved))

def finish_stream(step: Step) -> List<&2, Piece>:
  match step:
    case Step{mode, emitted}:
      List.reverse.go(&2, Piece, List.reverse(&2, Piece, emitted), finish(mode))

def parse(source: String) -> List<&2, Piece>:
  finish_stream(stream(lines(source), Idle{}, Nil{}))

def source(pieces: List<&2, Piece>) -> String:
  match pieces:
    case Nil{}:
      ""
    case Piece{kind, text} <> rest:
      text ++ source(rest)
