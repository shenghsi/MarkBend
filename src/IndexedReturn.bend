import Base
import ./Document.bend as D
import ./BlockIndex.bend as T
import ./Blocks.bend as B
import ./ListReturn.bend as R

# Read one tree path. Keep predecessor context without constructing a prefix.
def last(tree: T.Tree<D.Block>) -> String:
  match tree:
    case T.Empty{}:
      ""
    case T.Leaf{D.Block{id, kind, source}, width}:
      source
    case T.Branch{left, right, width, count, height}:
      last(right)

def line_ending(line: R.Line, prior: String) -> String:
  match line:
    case R.Line{body, current}:
      R.ending(current, prior)

def previous(lines: List<&2, String>, ending: String) -> String:
  match lines:
    case Nil{}:
      ending
    case line <> rest:
      previous(rest, line_ending(R.split(line, Nil{}), ending))

def located(here: Bool, +parts: R.Line, offset: Nat, +start: Nat,
  +end: Nat, previous: String, forbidden: Bool, next: Unit -> R.Edit) -> R.Edit:
  match here:
    case True{}:
      R.line_edit(parts, offset, start, end, previous, forbidden)
    case False{}:
      next(Unit{})

def locate(+parts: R.Line, offset: Nat, +boundary: Nat, +start: Nat,
  end: Nat, prior: String, forbidden: Bool, next: Unit -> R.Edit) -> R.Edit:
  match parts:
    case R.Line{body, current}:
      located(Nat.is_lt(start, boundary) ||
        (String.is_empty(current) && Nat.is_eq(start, boundary)),
        parts, offset, start, end, prior, forbidden, next)

def scan(lines: List<&2, String>, +offset: Nat, +start: Nat, +end: Nat,
  +prior: String, +forbidden: Bool) -> R.Edit:
  match lines:
    case Nil{}:
      R.line_edit(R.Line{"", ""}, offset, start, end, prior, forbidden)
    case +line <> rest:
      +boundary = Nat.add(offset, D.count_scalars(line, 0n))
      +parts = R.split(line, Nil{})
      locate(parts, offset, boundary, start, end, prior, forbidden,
        _ => scan(rest, boundary, start, end, line_ending(parts, prior), forbidden))

def block(block: D.Block, offset: Nat, start: Nat, end: Nat,
  predecessor: String) -> R.Edit:
  match block:
    case D.Block{id, kind, source}:
      scan(B.lines(source), offset, start, end,
        previous(B.lines(predecessor), ""), R.protected(B.Idle{}, kind))

def branch(rightward: Bool, left: Unit -> R.Edit, right: Unit -> R.Edit) -> R.Edit:
  match rightward:
    case False{}:
      left(Unit{})
    case True{}:
      right(Unit{})

def lookup(tree: T.Tree<D.Block>, +offset: Nat, +start: Nat, +end: Nat,
  predecessor: String) -> R.Edit:
  match tree:
    case T.Empty{}:
      R.line_edit(R.Line{"", ""}, offset, start, end,
        previous(B.lines(predecessor), ""), False{})
    case T.Leaf{value, width}:
      block(value, offset, start, end, predecessor)
    case T.Branch{+left, right, width, count, height}:
      +boundary = Nat.add(offset, T.length(D.Block, left))
      branch(Nat.is_ge(start, boundary),
        _ => lookup(left, offset, start, end, predecessor),
        _ => lookup(right, boundary, start, end, last(left)))

def plan(document: D.Document, +start: Nat, +end: Nat) -> R.Edit:
  match document:
    case D.Document{blocks, next, reparsed}:
      lookup(blocks, 0n, Nat.min(start, end), Nat.max(start, end), "")
