import Base
import ../src/BlockSceneCache.bend as Cache
import ../src/BlockScene.bend as Scene
import ../src/Document.bend as D
import ../src/BlockIndex.bend as Index
import ../src/TextPosition.bend as Position
import ./SessionViewCheck.bend as View
import ./DirectCheck.bend as Check
import ./HostPatchCheck.bend as Patch

def stats(cache: Cache.Cache, rebuilt: Nat, reused: Nat) -> Bool:
  match cache:
    case Cache.Cache{tree, count, a, b}:
      Nat.is_eq(a, rebuilt) && Nat.is_eq(b, reused)

def count(document: D.Document) -> Nat:
  match document:
    case D.Document{blocks, next, parsed}:
      Index.count(D.Block, blocks)

def bounded(cache: Cache.Cache, blocks: Nat) -> Bool:
  match cache:
    case Cache.Cache{tree, count, rebuilt, reused}:
      Nat.is_le(count, Nat.mul(3n, blocks))

def run_scene(scene: Scene.Scene) -> Scene.Scene:
  match scene:
    case Scene.Scene{runs, points}:
      Scene.Scene{runs, Nil{}}

def matches(+result: Cache.CachedScene, +source: String, +start: Nat, +end: Nat) -> Bool:
  View.same_scene(Cache.scene(result), Scene.build(source, start, end)) &&
    View.same_scene(Cache.host_scene(result), run_scene(Scene.build(source, start, end)))

def cache(result: Cache.CachedScene) -> Cache.Cache:
  match result:
    case Cache.CachedScene{scene, cache, index, host, patches}:
      cache

def walk(fuel: Nat, +document: D.Document, +source: String, +prior: Cache.CachedScene,
  old_start: Nat, old_end: Nat, +step: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      +at = Nat.mod(Nat.mul(step, 13n), 1n+String.length(source))
      +next_source = Position.replace(source, at, 1n+at, "😀\n**x**")
      +change = D.apply_change(document, at, 1n+at, "😀\n**x**")
      +next = D.changed(change)
      +scene = Cache.render_change(change, at, 3n+at, old_start, old_end, cache(prior), Cache.index(prior))
      do IO<Unit>:
        Check.check(matches(scene, next_source, at, 3n+at))
        Check.check(Patch.valid(prior, scene))
        Check.check(bounded(cache(scene), count(next)))
        walk(rest, next, next_source, scene, at, 3n+at, 1n+step)

def sample(+source: String) -> IO(Unit):
  +document = D.parse(source)
  +first = Cache.render(document, 0n, 0n, Cache.empty())
  +again = Cache.render(document, 0n, 0n, cache(first))
  +end = String.length(source)
  +moved = Cache.render(document, end, end, cache(again))
  +shifted_source = "prefix\n\n" ++ source
  +shifted_change = D.apply_change(document, 0n, 0n, "prefix\n\n")
  +shifted = D.changed(shifted_change)
  +after = Cache.render_change(shifted_change, 8n+end, 8n+end, end, end, cache(moved), Cache.index(moved))
  +remote = Cache.render_change(shifted_change, 0n, 0n, end, end, cache(moved), Cache.index(moved))
  +deleted_change = D.apply_change(shifted, 0n, String.length(shifted_source), "tail")
  +deleted = D.changed(deleted_change)
  +small = Cache.render_change(deleted_change, 4n, 4n, 8n+end, 8n+end, cache(after), Cache.index(after))
  do IO<Unit>:
    Check.check(matches(first, source, 0n, 0n))
    Check.check(stats(cache(first), count(document), 0n))
    Check.check(matches(again, source, 0n, 0n))
    Check.check(stats(cache(again), 0n, count(document)))
    Check.check(matches(moved, source, end, end))
    Check.check(matches(after, shifted_source, 8n+end, 8n+end))
    Check.check(Patch.valid(moved, after))
    Check.check(matches(remote, shifted_source, 0n, 0n))
    Check.check(Patch.valid(moved, remote))
    Check.check(matches(small, "tail", 4n, 4n))
    Check.check(Patch.valid(after, small))
    Check.check(bounded(cache(small), count(deleted)))
    walk(40n, shifted, shifted_source, after, 8n+end, 8n+end, 0n)

def main() -> IO(Unit):
  do IO<Unit>:
    sample("")
    sample("# heading\n\n**中文** *é* 😀\n\n> quote\n- item\n")
    sample("```rs\n**literal**\n```\n\n~~~\nunclosed\n")
    sample(String.repeat("# H\n\n**text**😀\n\n", 65n))
    IO.print("Block scene cache batch passed")
