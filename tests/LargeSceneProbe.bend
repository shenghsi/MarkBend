import Base
import ../src/Document.bend as Document
import ../src/BlockSceneCache.bend as Cache
import ../src/SceneIndex.bend as Mapping
import ../src/BlockIndex.bend as Index
import ./DocumentBench.bend as Fixture
import ./DirectCheck.bend as Check

def cache_count(value: Cache.Cache) -> Nat:
  match value:
    case Cache.Cache{tree, count, rebuilt, reused}:
      count

def scanned(value: Cache.Rendered) -> IO(Unit):
  match value:
    case Cache.Rendered{scene, updates, +rebuilt, reused, chunks, host}:
      do IO<Unit>:
        Check.check(Nat.is_gt(rebuilt, 0n))
        IO.print("Large scene scan completed")
        Check.check(Nat.is_eq(cache_count(Cache.apply_updates(updates, Cache.Empty{}, 0n, rebuilt, reused)), rebuilt))
        IO.print("Large scene cache completed")
        index : Mapping.Tree = Mapping.reuse(Mapping.Empty{}, chunks)
        Check.check(Nat.is_eq(Mapping.source_length(index), 1048576n))
        IO.print("Large scene index completed")

def parsed(value: Document.Document) -> IO(Unit):
  match value:
    case Document.Document{blocks, next, reparsed}:
      do IO<Unit>:
        IO.print("Large scene document parsed")
        result : Cache.Rendered = Cache.scan_tree(blocks, Cache.Empty{}, 0n, 0n, 0n)
        scanned(result)

def main() -> IO(Unit):
  parsed(Document.parse(Fixture.sample(1048576n)))
