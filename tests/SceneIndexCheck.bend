import Base
import ../src/SceneIndex.bend as Index
import ../src/BlockSceneCache.bend as Cache
import ../src/BlockScene.bend as Scene
import ../src/CursorMap.bend as Cursor
import ../src/TextPosition.bend as Position
import ../src/Document.bend as Document
import ./DirectCheck.bend as Check
import ../src/DirectState.bend as State
import ./SessionViewCheck.bend as View

def positions(fuel: Nat, +tree: Index.Tree, +visible: String,
  +points: List<&2, Nat>, +at: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        Check.check(Nat.is_eq(Index.to_source(tree, at),
          Cursor.to_source(points, Position.to_scalar(visible, at))))
        Check.check(Nat.is_eq(Index.to_native(tree, at),
          Position.to_native(visible, Cursor.to_view(points, at))))
        positions(rest, tree, visible, points, 1n+at)

def sparse(fuel: Nat, +tree: Index.Tree, +visible: String,
  +points: List<&2, Nat>, +at: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        Check.check(Nat.is_eq(Index.to_source(tree, at),
          Cursor.to_source(points, Position.to_scalar(visible, at))))
        Check.check(Nat.is_eq(Index.to_native(tree, at),
          Position.to_native(visible, Cursor.to_view(points, at))))
        sparse(rest, tree, visible, points, 4096n+at)

def large(+source: String) -> IO(Unit):
  +result = Cache.render(Document.parse(source), 1000000n, 1000000n, Cache.empty())
  +complete = Scene.build(source, 1000000n, 1000000n)
  do IO<Unit>:
    Check.check(View.same_scene(Cache.scene(result), complete))
    sparse(20n, Cache.index(result), Scene.text(complete), Scene.points(complete), 0n)

def check_scene(+scene: Scene.Scene, +tree: Index.Tree, +source_length: Nat) -> IO(Unit):
  +visible = Scene.text(scene)
  +native = Position.to_native(visible, String.length(visible))
  do IO<Unit>:
    Check.check(Nat.is_eq(Index.source_length(tree), source_length))
    Check.check(Nat.is_eq(Index.native_length(tree), native))
    positions(5n+Nat.max(source_length, native), tree, visible, Scene.points(scene), 0n)

def check(+result: Cache.CachedScene, source_length: Nat) -> IO(Unit):
  check_scene(Cache.scene(result), Cache.index(result), source_length)

def check_reference(+result: Cache.CachedScene, +reference: Scene.Scene, source_length: Nat) -> IO(Unit):
  do IO<Unit>:
    Check.check(View.same_scene(Cache.scene(result), reference))
    check_scene(reference, Cache.index(result), source_length)

def sample(+source: String) -> IO(Unit):
  +document = Document.parse(source)
  +end = String.length(source)
  +middle = Nat.div(end, 2n)
  do IO<Unit>:
    check_reference(Cache.render(document, 0n, 0n, Cache.empty()), Scene.build(source, 0n, 0n), end)
    check_reference(Cache.render(document, end, end, Cache.empty()), Scene.build(source, end, end), end)
    check_reference(Cache.render(document, 0n, end, Cache.empty()), Scene.build(source, 0n, end), end)
    check_reference(Cache.render(document, end, middle, Cache.empty()), Scene.build(source, end, middle), end)
    check_reference(Cache.render(document, middle, middle, Cache.empty()), Scene.build(source, middle, middle), end)

def source_size(snapshot: State.Snapshot) -> Nat:
  State.source_length(snapshot)

def session_scene(view: State.View, index: Index.Tree) -> Cache.CachedScene:
  match view:
    case State.View{scene, visible}:
      Cache.CachedScene{scene, Cache.empty(), index, Nil{}, Nil{}}

def check_session(+session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(View.valid(session))
    check(session_scene(State.view(session), State.index(session)), source_size(State.current(session)))

def edits(fuel: Nat, +session: State.Session, +step: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      +at = Nat.mod(Nat.mul(step, 7n), 1n+Index.native_length(State.index(session)))
      +edited = State.edit(session, at, 1n+at, "😀\n")
      +undone = State.undo(edited)
      do IO<Unit>:
        check_session(edited)
        check_session(undone)
        check_session(State.redo(undone))
        check_session(State.edit(undone, at, at, "Y"))
        edits(rest, edited, 1n+step)

def main() -> IO(Unit):
  do IO<Unit>:
    sample("")
    sample("**😀**\n# h\n")
    sample("😀\n\n**ab**\n")
    sample("```\n```\n# h\n\n~~~\n~~~\n")
    sample("# 中文😀\n\n*é* and 👩‍💻\n\n> q\n- item\n")
    sample("```\n😀\n```\n\n**tail**\n")
    sample("# H\r\n\r\n**😀**\r\n")
    sample(String.repeat("# H\n\n**😀**\n\n", 65n))
    large(String.repeat("# H\n\n**😀**\n\n", 4097n))
    +session : State.Session = State.start("# 中文\n\n**😀**\n\n```\n```\n*tail*\n")
    edits(20n, session, 0n)
    check_session(State.replace_source(session, "# replacement\n\n**x**😀"))
    IO.print("Scene position index batch passed")
