import Base
import ../src/BlockSceneCache.bend as Cache
import ../src/BlockScene.bend as Scene
import ../src/Document.bend as D
import ../src/SceneIndex.bend as Mapping
import ../src/TextPosition.bend as Position
import ./DocumentBench.bend as Fixture
import ./SceneCacheCheck.bend as Reference
import ./SceneIndexCheck.bend as Cursor
import ./DirectCheck.bend as Check
import ./HostPatchCheck.bend as Patch

def sample(+document: D.Document, +source: String, +prior: Cache.CachedScene,
  +old: Nat, +at: Nat, label: String) -> IO(Unit):
  +change = D.apply_change(document, at, 1n+at, "X")
  +next_source = Position.replace(source, at, 1n+at, "X")
  +result = Cache.render_change_counted(change, 1n+at, 1n+at, old, old,
    Cache.cache(prior), Cache.index(prior))
  +scene = Cache.result(result)
  do IO<Unit>:
    Check.check(Reference.matches(scene, next_source, 1n+at, 1n+at))
    Check.check(Patch.valid(prior, scene))
    Check.check(Patch.sparse(scene) && Nat.is_le(Patch.count(scene), 8n))
    Check.check(Nat.is_le(Cache.visited(result), 8n))
    Check.check(Reference.bounded(Cache.cache(scene), Reference.count(D.changed(change))))
    Cursor.positions(3n, Cache.index(scene), Scene.text(Cache.scene(scene)),
      Scene.points(Scene.build(next_source, 1n+at, 1n+at)), Nat.sub(at, 1n))
    Cursor.positions(2n, Cache.index(scene), Scene.text(Cache.scene(scene)),
      Scene.points(Scene.build(next_source, 1n+at, 1n+at)), String.length(next_source))
    IO.print(label ++ " visited=" ++ Nat.show(Cache.visited(result)) ++
      " transferred=" ++ Nat.show(Patch.count(scene)) ++
      " blocks=" ++ Nat.show(Mapping.count(Cache.index(scene))))

def selection(+document: D.Document, +source: String, +prior: Cache.CachedScene,
  +old: Nat, +next: Nat) -> IO(Unit):
  +result = Cache.render_change_counted(D.Change{document, 0n, 0n, 0n}, next, next,
    old, old, Cache.cache(prior), Cache.index(prior))
  do IO<Unit>:
    Check.check(Reference.matches(Cache.result(result), source, next, next))
    Check.check(Patch.valid(prior, Cache.result(result)))
    Check.check(Patch.sparse(Cache.result(result)) && Nat.is_le(Patch.count(Cache.result(result)), 4n))
    Check.check(Nat.is_le(Cache.visited(result), 4n))
    IO.print("remote_selection visited=" ++ Nat.show(Cache.visited(result)))

def main() -> IO(Unit):
  +source = Fixture.sample(1048576n)
  +document = D.parse(source)
  +end = String.length(source)
  +prior = Cache.render(document, end, end, Cache.empty())
  do IO<Unit>:
    sample(document, source, prior, end, 2n, "near_start")
    sample(document, source, prior, end, 524288n, "middle")
    sample(document, source, prior, end, 1048574n, "near_end")
    selection(document, source, prior, end, 0n)
    IO.print("One-MiB scene range batch passed")
