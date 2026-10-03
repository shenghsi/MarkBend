import Base
import ../src/Document.bend as Document
import ../src/Blocks.bend as Blocks
import ../src/BlockIndex.bend as Index
import ../src/BlockScene.bend as Scene
import ../src/Projection.bend as Inline
import ../src/Experiment.bend as Experiment
import ../src/ScalarText.bend as Scalar
import ./TextByteMapCheck.bend as Fixture
import ./DirectCheck.bend as Check
import ./SessionViewCheck.bend as View

def exact_points(points: List<&2, Nat>, +expected: Nat, ok: Bool) -> Bool:
  match points ok:
    case _ False{}:
      False{}
    case Nil{} True{}:
      Nat.is_eq(expected, 65537n)
    case point <> rest True{}:
      exact_points(rest, 1n+expected, Nat.is_eq(point, expected))

def scene_checked(value: Scene.Scene) -> IO(Unit):
  match value:
    case Scene.Scene{runs, points}:
      do IO<Unit>:
        Check.check(Nat.is_eq(Index.list_count(Scene.Run, runs, 0n), 1n))
        Check.check(exact_points(points, 0n, True{}))
        IO.print("Long paragraph scene passed")

def part_checked(value: Inline.Part) -> IO(Unit):
  match value:
    case Inline.Part{run, width, remaining}:
      do IO<Unit>:
        Check.check(Nat.is_eq(width, 65536n))
        Check.check(Nat.is_eq(Index.list_count(Char, remaining, 0n), 0n))
        IO.print("Long paragraph projection part passed")

def main() -> IO(Unit):
  do IO<Unit>:
    +source : String = Fixture.repeat_text(1024n, String.repeat("x", 64n), "")
    Check.check(View.same_points(Scene.without_end(Nil{}), Nil{}))
    Check.check(View.same_points(Scene.without_end([7n]), Nil{}))
    Check.check(View.same_points(Scene.without_end([2n, 4n, 9n]), [2n, 4n]))
    Check.check(Nat.is_eq(Document.count_scalars(source, 0n), 65536n))
    IO.print("Long paragraph fixture passed")
    Check.check(Nat.is_eq(Index.list_count(Blocks.Piece, Blocks.parse(source), 0n), 1n))
    IO.print("Long paragraph block parsing passed")
    Check.check(Nat.is_eq(Index.list_count(Experiment.RenderRun, Experiment.Markdown.render_runs(source), 0n), 1n))
    IO.print("Long paragraph Markdown runs passed")
    part_checked(Inline.part(Experiment.PlainRun{source}, Scalar.to_chars(source)))
    +runs : List<&2, Experiment.RenderRun> = Inline.runs(source, 0n, 0n)
    Check.check(Nat.is_eq(Index.list_count(Experiment.RenderRun, runs, 0n), 1n))
    IO.print("Long paragraph inline runs passed")
    Check.check(Nat.is_eq(Index.list_count(Nat, Inline.mapping(source, runs), 0n), 65537n))
    IO.print("Long paragraph inline mapping passed")
    scene_checked(Scene.piece(Blocks.Piece{Blocks.Paragraph{}, source}, 0n, 0n, 0n))
    scene_checked(Scene.build(source, 0n, 0n))
