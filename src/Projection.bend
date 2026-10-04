import Base
import ./Experiment.bend as E
import ./CursorMap.bend as Cursor
import ./ScalarText.bend as Scalar

# An active run shows its exact source, including formatting marks and escapes.
# Inactive runs keep the current inline renderer's style and visible text.
type Part is Data:
  Part{run: E.RenderRun, width: Nat, remaining: List<&2, Char>}

def part_finish(run: E.RenderRun, +marks: Nat, chunk: Cursor.Chunk) -> Part:
  match chunk:
    case Cursor.Chunk{positions, remaining, offset}:
      Part{run, Nat.add(marks, offset), Cursor.skip(remaining, marks)}

# This local scan obtains only width and remaining source. The actual cursor
# map still uses Cursor.consume through Projection.mapping.
type Width is Data:
  Width{remaining: List<&2, Char>, offset: Nat}

def consume_width(visible: List<&2, Char>, chars: List<&2, Char>,
  +offset: Nat, plain: Bool) -> Width:
  match visible chars plain:
    case Nil{} _ _:
      Width{chars, offset}
    case '*' <> tail Chr{92} <> '*' <> rest True{}:
      consume_width(tail, rest, 2n+offset, True{})
    case '`' <> tail Chr{92} <> '`' <> rest True{}:
      consume_width(tail, rest, 2n+offset, True{})
    case visible_char <> tail char <> rest plain:
      consume_width(tail, rest, 1n+offset, plain)
    case visible_char <> tail Nil{} _:
      Width{Nil{}, offset}

def width_finish(run: E.RenderRun, +marks: Nat, width: Width) -> Part:
  match width:
    case Width{remaining, offset}:
      Part{run, Nat.add(marks, offset), Cursor.skip(remaining, marks)}

def part(run: E.RenderRun, chars: List<&2, Char>) -> Part:
  match run:
    case E.PlainRun{+text}:
      width_finish(E.PlainRun{text}, 0n,
        consume_width(Scalar.to_chars(text), chars, 0n, True{}))
    case E.StrongRun{+text}:
      width_finish(E.StrongRun{text}, 2n,
        consume_width(Scalar.to_chars(text), Cursor.skip(chars, 2n), 2n, False{}))
    case E.EmphasisRun{+text}:
      width_finish(E.EmphasisRun{text}, 1n,
        consume_width(Scalar.to_chars(text), Cursor.skip(chars, 1n), 1n, False{}))
    case E.CodeRun{+text}:
      width_finish(E.CodeRun{text}, 1n,
        consume_width(Scalar.to_chars(text), Cursor.skip(chars, 1n), 1n, False{}))

def choose(active: Bool, original: String, run: E.RenderRun) -> E.RenderRun:
  match active:
    case True{}:
      E.PlainRun{original}
    case False{}:
      run

def push(
  slice: Part, +chars: List<&2, Char>, +offset: Nat, +start: Nat, +end: Nat,
  rest: List<&2, Char> -> Nat -> List<&2, E.RenderRun>
) -> List<&2, E.RenderRun>:
  match slice:
    case Part{run, +width, remaining}:
      +next = Nat.add(offset, width)
      active = Bool.and(Nat.is_le(start, next), Nat.is_le(offset, end))
      original = Scalar.take_chars(chars, width, Nil{})
      choose(active, original, run) <> rest(remaining, next)

def scan(
  runs: List<&2, E.RenderRun>, +chars: List<&2, Char>, offset: Nat,
  +start: Nat, +end: Nat
) -> List<&2, E.RenderRun>:
  match runs:
    case Nil{}:
      Nil{}
    case run <> rest:
      push(part(run, chars), chars, offset, start, end,
        remaining => next => scan(rest, remaining, next, start, end))

def ordered_runs(+source: String, start: Nat, end: Nat) -> List<&2, E.RenderRun>:
  scan(E.Markdown.render_runs(source), Scalar.to_chars(source), 0n, start, end)

def order_runs(order: Bool, source: String, start: Nat, end: Nat) -> List<&2, E.RenderRun>:
  match order:
    case True{}:
      ordered_runs(source, start, end)
    case False{}:
      ordered_runs(source, end, start)

def runs(source: String, +start: Nat, +end: Nat) -> List<&2, E.RenderRun>:
  order_runs(Nat.is_le(start, end), source, start, end)

def run_text(run: E.RenderRun) -> String:
  match run:
    case E.PlainRun{text}:
      text
    case E.StrongRun{text}:
      text
    case E.EmphasisRun{text}:
      text
    case E.CodeRun{text}:
      text

def text(runs: List<&2, E.RenderRun>) -> String:
  match runs:
    case Nil{}:
      ""
    case run <> rest:
      run_text(run) ++ text(rest)

type MappingWork is Data:
  MappingWork{source: String, chars: List<&2, Char>}

def mapping_work(+source: String) -> MappingWork:
  MappingWork{source, Scalar.to_chars(source)}

def mapping_chars(work: MappingWork) -> List<&2, Char>:
  match work:
    case MappingWork{source, chars}:
      chars

def mapping(source: String, runs: List<&2, E.RenderRun>) -> List<&2, Nat>:
  Cursor.build(runs, mapping_chars(mapping_work(source)), 0n)
