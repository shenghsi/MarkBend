import Base
import ../src/BlockScene.bend as Scene
import ../src/DirectState.bend as State
import ../src/Document.bend as Document
import ../src/TextPosition.bend as Position
import ./DocumentBench.bend as Fixture
import ../src/BlockSceneCache.bend as Cache

def native_end(+scene: Scene.Scene) -> Nat:
  Position.to_native(Scene.text(scene), List.length(&2, Nat, Scene.points(scene)))

def scene_bench(+document: Document.Document) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    result : Nat = native_end(Scene.document(document, 0n, 0n))
    stop : Nat <- IO.now()
    IO.print("scene_build_ms=" ++ Nat.show(Nat.sub(stop, start)) ++
      " native_length=" ++ Nat.show(result))

def source_length(snapshot: State.Snapshot) -> Nat:
  State.source_length(snapshot)

def cache_report(cache: Cache.Cache) -> IO(Unit):
  match cache:
    case Cache.Cache{tree, count, rebuilt, reused}:
      IO.print("scene_cache_entries=" ++ Nat.show(count) ++ " rebuilt=" ++ Nat.show(rebuilt) ++
        " reused=" ++ Nat.show(reused))

def edit_bench(+session: State.Session) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    +result : State.Session = State.edit(session, 10000000n, 10000000n, "X")
    stop : Nat <- IO.now()
    IO.print("edit_core_ms=" ++ Nat.show(Nat.sub(stop, start)) ++
      " source_length=" ++ Nat.show(source_length(State.current(result))))
    cache_report(State.cache(result))

def main() -> IO(Unit):
  +source = Fixture.sample(1048576n)
  do IO<Unit>:
    scene_bench(Document.parse(source))
    edit_bench(State.start(source))
