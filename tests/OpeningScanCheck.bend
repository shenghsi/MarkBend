import Base
import ../src/Document.bend as D
import ../src/BlockIndex.bend as Index
import ../src/BlockSceneCache.bend as Cache
import ./DocumentBench.bend as Fixture
import ./DirectCheck.bend as Check
import ./SessionViewCheck.bend as View
import ../src/SceneIndex.bend as Mapping
import ../src/BlockScene.bend as Scene

def same_chunk(a: Mapping.Chunk, b: Mapping.Chunk) -> Bool:
  match a b:
    case Mapping.Chunk{text, points, source, native, last, id, start, end, runs}
      Mapping.Chunk{other, later, other_source, other_native, other_last, other_id, other_start, other_end, other_runs}:
      String.eq(text, other) && View.same_points(points, later) && View.same_runs(runs, other_runs) &&
        View.same_points([source, native, last, id, start, end],
          [other_source, other_native, other_last, other_id, other_start, other_end])

def same_chunks(a: List<&2, Mapping.Chunk>, b: List<&2, Mapping.Chunk>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case x <> xs y <> ys:
      same_chunk(x, y) && same_chunks(xs, ys)
    case _ _:
      False{}

def same_entries(a: List<&2, Cache.Entry>, b: List<&2, Cache.Entry>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Cache.Entry{id, start, end, scene, chunk} <> rest
      Cache.Entry{other, a, b, later, other_chunk} <> tail:
      View.same_points([id, start, end], [other, a, b]) && View.same_scene(scene, later) &&
        same_chunk(chunk, other_chunk) && same_entries(rest, tail)
    case _ _:
      False{}

def same_flag(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}:
      True{}
    case False{} False{}:
      True{}
    case _ _:
      False{}

def same_host(a: List<&2, Scene.HostChunk>, b: List<&2, Scene.HostChunk>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Scene.HostChunk{id, fresh, runs} <> rest Scene.HostChunk{other, flag, later} <> tail:
      Nat.is_eq(id, other) && same_flag(fresh, flag) && View.same_runs(runs, later) && same_host(rest, tail)
    case _ _:
      False{}

def same_rendered(a: Cache.Rendered, b: Cache.Rendered) -> Bool:
  match a b:
    case Cache.Rendered{scene, updates, rebuilt, reused, chunks, host}
      Cache.Rendered{later, other_updates, other_rebuilt, other_reused, other_chunks, other_host}:
      View.same_scene(scene, later) && same_entries(updates, other_updates) &&
        Nat.is_eq(rebuilt, other_rebuilt) && Nat.is_eq(reused, other_reused) &&
        same_chunks(chunks, other_chunks) && same_host(host, other_host)

def same_item(a: Maybe<&2, Cache.Entry>, b: Maybe<&2, Cache.Entry>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      same_entries([x], [y])
    case _ _:
      False{}

def same_trie(a: Cache.Trie, b: Cache.Trie) -> Bool:
  match a b:
    case Cache.Empty{} Cache.Empty{}:
      True{}
    case Cache.Node{item, zero, one} Cache.Node{other, left, right}:
      same_item(item, other) && same_trie(zero, left) && same_trie(one, right)
    case _ _:
      False{}

def same_cache(a: Cache.Cache, b: Cache.Cache) -> Bool:
  match a b:
    case Cache.Cache{tree, count, rebuilt, reused} Cache.Cache{other, n, r, u}:
      same_trie(tree, other) && View.same_points([count, rebuilt, reused], [n, r, u])

def same_finish(rendered: Cache.Rendered) -> Bool:
  match rendered:
    case Cache.Rendered{scene, +updates, +rebuilt, +reused, chunks, host}:
      same_cache(Cache.apply_updates(updates, Cache.Empty{}, 0n, rebuilt, reused),
        Cache.apply_updates_sequential(updates, Cache.Empty{}, 0n, rebuilt, reused))

def same_open_finish(document: D.Document) -> Bool:
  match document:
    case D.Document{blocks, next, reparsed}:
      same_finish(Cache.scan_tree(blocks, Cache.Empty{}, 0n, 0n, 0n))

def entry(+id: Nat, +text: String) -> Cache.Entry:
  +scene = Scene.build(text, 0n, 0n)
  Cache.Entry{id, 0n, 0n, scene, Mapping.chunk(scene, String.length(text), id, 0n, 0n)}

def duplicate_finish() -> Bool:
  +updates : List<&2, Cache.Entry> = [entry(9n, "a"), entry(0n, "zero"), entry(Nat.mul(1000000n, 1000000n), "large"),
    entry(9n, "last"), entry(0n, "last zero"), entry(2n, "two")]
  same_cache(Cache.apply_updates(updates, Cache.Empty{}, 0n, 8192n, 0n),
    Cache.apply_updates_sequential(updates, Cache.Empty{}, 0n, 8192n, 0n))

def same_scan(document: D.Document, cache: Cache.Cache, +start: Nat, +end: Nat) -> Bool:
  match document cache:
    case D.Document{+blocks, next, reparsed} Cache.Cache{+tree, count, rebuilt, reused}:
      same_rendered(Cache.scan(Index.flatten(D.Block, blocks, Nil{}), tree, start, end, 0n),
        Cache.scan_tree(blocks, tree, start, end, 0n))

def main() -> IO(Unit):
  +document = D.parse(Fixture.sample(1048576n))
  +cache = Cache.cache(Cache.render(document, 0n, 0n, Cache.empty()))
  do IO<Unit>:
    Check.check(same_scan(document, Cache.empty(), 0n, 0n))
    Check.check(same_scan(document, cache, 524288n, 524291n))
    Check.check(same_open_finish(document))
    Check.check(duplicate_finish())
    IO.print("Parallel opening scan batch passed")
