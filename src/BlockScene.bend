import Base
import ./Blocks.bend as B
import ./Experiment.bend as E
import ./Projection.bend as Inline
import ./Document.bend as D

type Run is Data:
  Run{text: String, style: U32}

type HostChunk is Data:
  HostChunk{id: Nat, fresh: Bool, runs: List<&2, Run>}

# Apply in list order. Block and UTF-16 ranges refer to the scene after the
# preceding patch. Native ranges are explicit; the host applies no Markdown rules.
type HostPatch is Data:
  HostPatch{first: Nat, removed: Nat, start: Nat, length: Nat,
    chunks: List<&2, HostChunk>}

type Scene is Data:
  Scene{runs: List<&2, Run>, points: List<&2, Nat>}

def paint(runs: List<&2, E.RenderRun>, +plain_style: U32) -> List<&2, Run>:
  match runs:
    case Nil{}:
      Nil{}
    case E.PlainRun{text} <> rest:
      Run{text, plain_style} <> paint(rest, plain_style)
    case E.StrongRun{text} <> rest:
      Run{text, 1} <> paint(rest, plain_style)
    case E.EmphasisRun{text} <> rest:
      Run{text, 2} <> paint(rest, plain_style)
    case E.CodeRun{text} <> rest:
      Run{text, 3} <> paint(rest, plain_style)

def offset_points_loop(points: List<&2, Nat>, +offset: Nat,
  reversed: List<&2, Nat>) -> List<&2, Nat>:
  match points:
    case Nil{}:
      List.reverse(&2, Nat, reversed)
    case point <> rest:
      offset_points_loop(rest, offset, Nat.add(offset, point) <> reversed)

def offset_points(points: List<&2, Nat>, offset: Nat) -> List<&2, Nat>:
  offset_points_loop(points, offset, Nil{})

def without_end_loop(points: List<&2, Nat>, reversed: List<&2, Nat>) -> List<&2, Nat>:
  match points:
    case Nil{}:
      List.reverse(&2, Nat, reversed)
    case point <> Nil{}:
      List.reverse(&2, Nat, reversed)
    case point <> rest:
      without_end_loop(rest, point <> reversed)

def without_end(points: List<&2, Nat>) -> List<&2, Nat>:
  without_end_loop(points, Nil{})

def inline_runs(active: Bool, +source: String, start: Nat, end: Nat, +offset: Nat)
  -> List<&2, E.RenderRun>:
  match active:
    case True{}:
      Inline.runs(source, Nat.sub(start, offset), Nat.sub(end, offset))
    case False{}:
      +outside = Nat.add(1n, D.count_scalars(source, 0n))
      Inline.runs(source, outside, outside)

def inline_scene(+source: String, +start: Nat, +end: Nat, +offset: Nat, style: U32) -> Scene:
  active = Nat.is_le(Nat.min(start, end), Nat.add(offset, D.count_scalars(source, 0n))) &&
    Nat.is_le(offset, Nat.max(start, end))
  +runs = inline_runs(active, source, start, end, offset)
  Scene{paint(runs, style), offset_points(Inline.mapping(source, runs), offset)}

def literal_points_loop(text: String, +offset: Nat, finish: Nat,
  reversed: List<&2, Nat>) -> List<&2, Nat>:
  match text:
    case SNil{}:
      List.reverse.go(&2, Nat, reversed, [finish])
    case SCon{char, rest}:
      literal_points_loop(rest, 1n+offset, finish, offset <> reversed)

def literal_points(text: String, offset: Nat, finish: Nat) -> List<&2, Nat>:
  literal_points_loop(text, offset, finish, Nil{})

def literal(+text: String, +offset: Nat, finish: Nat, style: U32) -> Scene:
  Scene{[Run{text, style}], literal_points(text, offset, finish)}

def fence_body(+lines: List<&2, String>, closed: Bool) -> String:
  match closed:
    case True{}:
      String.concat(List.take(&2, String, lines, Nat.sub(List.length(&2, String, lines), 1n)))
    case False{}:
      String.concat(lines)

def fence_lines(lines: List<&2, String>, closed: Bool, +offset: Nat, finish: Nat) -> Scene:
  match lines:
    case Nil{}:
      Scene{Nil{}, [finish]}
    case opening <> rest:
      literal(fence_body(rest, closed), Nat.add(offset, String.length(opening)), finish, 3)

def fence(active: Bool, +source: String, closed: Bool, +offset: Nat, +finish: Nat) -> Scene:
  match active:
    case True{}:
      literal(source, offset, finish, 3)
    case False{}:
      fence_lines(B.lines(source), closed, offset, finish)

def heading_body(text: String) -> String:
  match text:
    case SCon{' ', rest}:
      rest
    case SCon{'\t', rest}:
      rest
    case _:
      text

def heading(active: Bool, +source: String, +level: Nat, start: Nat, end: Nat,
  +offset: Nat) -> Scene:
  match active:
    case True{}:
      literal(source, offset, Nat.add(offset, String.length(source)), U32.add(3, U32.from_nat(level)))
    case False{}:
      +trimmed = B.strip_indent(3n, source)
      +indent = Nat.sub(String.length(source), String.length(trimmed))
      +body = heading_body(String.drop(trimmed, level))
      +marks = Nat.sub(String.length(trimmed), String.length(body))
      inline_scene(body, start, end, Nat.add(offset, Nat.add(indent, marks)),
        U32.add(3, U32.from_nat(level)))

def kind_scene(kind: B.BlockKind, +source: String, +start: Nat, +end: Nat,
  +offset: Nat, finish: Nat, active: Bool) -> Scene:
  match kind:
    case B.Fence{marker, width, closed}:
      fence(active, source, closed, offset, finish)
    case B.Heading{level}:
      heading(active, source, level, start, end, offset)
    case B.Quote{}:
      inline_scene(source, start, end, offset, 10)
    case B.ListItem{ordered}:
      inline_scene(source, start, end, offset, 11)
    case B.Blank{}:
      literal(source, offset, finish, 0)
    case B.Paragraph{}:
      inline_scene(source, start, end, offset, 0)

def piece(piece: B.Piece, +start: Nat, +end: Nat, +offset: Nat) -> Scene:
  match piece:
    case B.Piece{kind, +source}:
      +finish = Nat.add(offset, D.count_scalars(source, 0n))
      +active = Nat.is_le(Nat.min(start, end), finish) && Nat.is_le(offset, Nat.max(start, end))
      kind_scene(kind, source, start, end, offset, finish, active)

def join(a: Scene, b: Scene) -> Scene:
  match a b:
    case Scene{left, positions} Scene{right, later}:
      Scene{List.reverse.go(&2, Run, List.reverse(&2, Run, left), right),
        List.reverse.go(&2, Nat, List.reverse(&2, Nat, without_end(positions)), later)}

def accumulated_scene(value: Scene, runs: List<&2, Run>, points: List<&2, Nat>) -> Scene:
  match value:
    case Scene{local_runs, local_points}:
      Scene{List.reverse.go(&2, Run, local_runs, runs),
        List.reverse.go(&2, Nat, without_end(local_points), points)}

def finish_accumulated(value: Scene, offset: Nat) -> Scene:
  match value:
    case Scene{runs, points}:
      Scene{List.reverse(&2, Run, runs), List.reverse.go(&2, Nat, points, [offset])}

def accumulate_piece(value: Scene, reversed: Scene) -> Scene:
  match reversed:
    case Scene{runs, points}:
      accumulated_scene(value, runs, points)

type CountWork is Data:
  CountWork{source: String, count: Nat}

def count_work(+source: String) -> CountWork:
  CountWork{source, D.count_scalars(source, 0n)}

def count_result(work: CountWork) -> Nat:
  match work:
    case CountWork{source, count}:
      count

def scan_count(source: String) -> Nat:
  count_result(count_work(source))

def scan_loop(pieces: List<&2, B.Piece>, +start: Nat, +end: Nat, +offset: Nat,
  reversed: Scene) -> Scene:
  match pieces:
    case Nil{}:
      finish_accumulated(reversed, offset)
    case B.Piece{+kind, +source} <> rest:
      scan_loop(rest, start, end, Nat.add(offset, scan_count(source)),
        accumulate_piece(piece(B.Piece{kind, source}, start, end, offset), reversed))

def scan(pieces: List<&2, B.Piece>, start: Nat, end: Nat, offset: Nat) -> Scene:
  scan_loop(pieces, start, end, offset, Scene{Nil{}, Nil{}})

def build(source: String, start: Nat, end: Nat) -> Scene:
  scan(B.parse(source), start, end, 0n)

def document(doc: D.Document, start: Nat, end: Nat) -> Scene:
  match doc:
    case D.Document{blocks, next, reparsed}:
      scan(D.pieces(blocks), start, end, 0n)

def run_text_loop(runs: List<&2, Run>, reversed: String) -> String:
  match runs:
    case Nil{}:
      String.reverse(reversed)
    case Run{text, style} <> rest:
      run_text_loop(rest, D.prepend_text(text, reversed))

def run_text(runs: List<&2, Run>) -> String:
  run_text_loop(runs, SNil{})

def text(scene: Scene) -> String:
  match scene:
    case Scene{runs, points}:
      run_text(runs)

def points(scene: Scene) -> List<&2, Nat>:
  match scene:
    case Scene{runs, points}:
      points
