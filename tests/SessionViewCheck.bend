import Base
import ../src/DirectState.bend as State
import ../src/BlockScene.bend as Scene
import ../src/TextPosition.bend as Position
import ./DirectCheck.bend as Check
import ./Utf8Check.bend as Text

def same_runs_loop(a: List<&2, Scene.Run>, b: List<&2, Scene.Run>, ok: Bool) -> Bool:
  match a b ok:
    case _ _ False{}:
      False{}
    case Nil{} Nil{} True{}:
      True{}
    case Scene.Run{text, style} <> rest Scene.Run{other, kind} <> later True{}:
      same_runs_loop(rest, later, Text.text_equal(text, other, True{}) && U32.is_eq(style, kind))
    case _ _ _:
      False{}

def same_runs(a: List<&2, Scene.Run>, b: List<&2, Scene.Run>) -> Bool:
  same_runs_loop(a, b, True{})

def same_points_loop(a: List<&2, Nat>, b: List<&2, Nat>, ok: Bool) -> Bool:
  match a b ok:
    case _ _ False{}:
      False{}
    case Nil{} Nil{} True{}:
      True{}
    case x <> rest y <> later True{}:
      same_points_loop(rest, later, Nat.is_eq(x, y))
    case _ _ _:
      False{}

def same_points(a: List<&2, Nat>, b: List<&2, Nat>) -> Bool:
  same_points_loop(a, b, True{})

def same_scene(a: Scene.Scene, b: Scene.Scene) -> Bool:
  match a b:
    case Scene.Scene{runs, points} Scene.Scene{other, later}:
      same_runs(runs, other) && same_points(points, later)

def matches(snapshot: State.Snapshot, view: State.View) -> Bool:
  match snapshot view:
    case State.Snapshot{start, end, document} State.View{+scene, visible}:
      Text.text_equal(visible, Scene.text(scene), True{}) &&
        same_scene(scene, Scene.build(State.document_source(document), start, end))

def valid(+session: State.Session) -> Bool:
  matches(State.current(session), State.view(session))

def positions(fuel: Nat, +session: State.Session, +index: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      +selected = State.select(session, index, index)
      +ranged = State.select(session, 2n+index, index)
      +edited = State.edit(selected, index, 1n+index, "😀\n")
      +raw = State.replace_source(selected, "# 中文\n\n*new*😀")
      do IO<Unit>:
        Check.check(valid(selected))
        Check.check(valid(ranged))
        Check.check(valid(edited))
        Check.check(valid(State.undo(edited)))
        Check.check(valid(State.redo(State.undo(edited))))
        Check.check(valid(raw))
        Check.check(valid(State.undo(raw)))
        Check.check(valid(State.redo(State.undo(raw))))
        positions(rest, session, 1n+index)

def sample(+source: String) -> IO(Unit):
  +session = State.start(source)
  do IO<Unit>:
    Check.check(valid(session))
    Check.check(valid(State.undo(session)))
    Check.check(valid(State.redo(session)))
    positions(3n+Position.to_native(source, String.length(source)), session, 0n)

def main() -> IO(Unit):
  do IO<Unit>:
    Check.check(Bool.not(same_runs([Scene.Run{"a", 0}, Scene.Run{"b", 1}],
      [Scene.Run{"a", 0}, Scene.Run{"b", 0}])))
    Check.check(Bool.not(same_runs([Scene.Run{"a", 0}, Scene.Run{"b", 1}],
      [Scene.Run{"a", 0}, Scene.Run{"c", 1}])))
    Check.check(Bool.not(same_points([0n, 2n, 3n], [0n, 1n, 3n])))
    Check.check(Bool.not(same_points([0n, 1n], [0n])))
    sample("")
    sample("**ab** and *中文*😀")
    sample("\\*a\n\n# h\n\n```rs\n**x**\n```\ntail")
    sample("👩‍💻é\n> q\n- item\n")
    IO.print("Session view batch passed")
