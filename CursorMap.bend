import Base
import ./Experiment.bend as E

# Each visible cursor position maps to one Unicode scalar position in the source.
# A boundary before a styled span maps after its opening marks. The final cursor
# maps after any closing marks. This is the right-side boundary policy.
type Chunk is Data:
  Chunk{
    positions: List<&2, Nat>,
    remaining: List<&2, Char>,
    source_offset: Nat
  }

def skip(chars: List<&2, Char>, count: Nat) -> List<&2, Char>:
  List.drop(&2, Char, chars, count)

def prepend(position: Nat, chunk: Chunk) -> Chunk:
  match chunk:
    case Chunk{positions, remaining, offset}:
      Chunk{position <> positions, remaining, offset}

# Plain runs can contain escaped asterisks or backticks. Styled runs keep their
# contents literal in the current renderer.
def consume(
  visible: List<&2, Char>, chars: List<&2, Char>, +offset: Nat, plain: Bool
) -> Chunk:
  match visible chars plain:
    case Nil{} _ _:
      Chunk{Nil{}, chars, offset}
    case '*' <> tail Chr{92} <> '*' <> rest True{}:
      prepend(1n+offset, consume(tail, rest, 2n+offset, True{}))
    case '`' <> tail Chr{92} <> '`' <> rest True{}:
      prepend(1n+offset, consume(tail, rest, 2n+offset, True{}))
    case visible_char <> tail char <> rest plain:
      prepend(offset, consume(tail, rest, 1n+offset, plain))
    case visible_char <> tail Nil{} _:
      Chunk{Nil{}, Nil{}, offset}

def finish_chunk(
  chunk: Chunk, rest: List<&2, Char> -> Nat -> List<&2, Nat>
) -> List<&2, Nat>:
  match chunk:
    case Chunk{positions, remaining, next}:
      List.append(&2, Nat, positions, rest(remaining, next))

def build(
  runs: List<&2, E.RenderRun>, chars: List<&2, Char>, +offset: Nat
) -> List<&2, Nat>:
  match runs:
    case Nil{}:
      [offset]
    case E.PlainRun{text} <> rest:
      finish_chunk(consume(String.to_list(text), chars, offset, True{}),
        remaining => next => build(rest, remaining, next))
    case E.StrongRun{text} <> rest:
      finish_chunk(consume(String.to_list(text), skip(chars, 2n), 2n+offset, False{}),
        remaining => next => build(rest, skip(remaining, 2n), 2n+next))
    case E.EmphasisRun{text} <> rest:
      finish_chunk(consume(String.to_list(text), skip(chars, 1n), 1n+offset, False{}),
        remaining => next => build(rest, skip(remaining, 1n), 1n+next))
    case E.CodeRun{text} <> rest:
      finish_chunk(consume(String.to_list(text), skip(chars, 1n), 1n+offset, False{}),
        remaining => next => build(rest, skip(remaining, 1n), 1n+next))

def mapping(+source: String) -> List<&2, Nat>:
  build(E.Markdown.render_runs(source), String.to_list(source), 0n)

# Out-of-range view positions clamp to the final source position.
def to_source(points: List<&2, Nat>, view: Nat) -> Nat:
  match points view:
    case Nil{} _:
      0n
    case position <> Nil{} _:
      position
    case position <> rest 0n:
      position
    case position <> rest 1n+n:
      to_source(rest, n)

# Hidden source marks map to the next visible boundary. Source positions after
# the document clamp to the final visible boundary.
def choose_view(hit: Bool, view: Nat, later: Nat) -> Nat:
  match hit:
    case True{}:
      view
    case False{}:
      later

def to_view_scan(points: List<&2, Nat>, +source: Nat, +view: Nat) -> Nat:
  match points:
    case Nil{}:
      view
    case position <> Nil{}:
      view
    case position <> rest:
      choose_view(Nat.is_le(source, position), view, to_view_scan(rest, source, 1n+view))

def to_view(points: List<&2, Nat>, source: Nat) -> Nat:
  to_view_scan(points, source, 0n)
