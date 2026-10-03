import Base
import ../src/Document.bend as D
import ../src/BlockIndex.bend as Index
import ../src/BlockSceneCache.bend as Cache
import ../src/SceneIndex.bend as Mapping
import ../src/BlockScene.bend as Scene
import ./DocumentBench.bend as Fixture

def report(+document: D.Document, result: Cache.CachedScene,
  start: Nat, +parsed: Nat, rendered: Nat) -> IO(Unit):
  match document result:
    case D.Document{+blocks, next, reparsed} Cache.CachedScene{scene, cache, index, host, patches}:
      match cache:
        case Cache.Cache{tree, count, rebuilt, reused}:
          do IO<Unit>:
            IO.print("opening_core parse_ms=" ++ Nat.show(Nat.sub(parsed, start)) ++
              " cache_ms=" ++ Nat.show(Nat.sub(rendered, parsed)) ++
              " blocks=" ++ Nat.show(Index.count(D.Block, blocks)) ++
              " entries=" ++ Nat.show(count) ++ " rebuilt=" ++ Nat.show(rebuilt) ++
              " transferred=" ++ Nat.show(List.length(&2, Scene.HostChunk, host)))

def finish_stages(rendered: Cache.Rendered) -> IO(Cache.CachedScene):
  match rendered:
    case Cache.Rendered{scene, updates, rebuilt, reused, chunks, host}:
      do IO<Cache.CachedScene>:
        start : Nat <- IO.now()
        cache : Cache.Cache = Cache.apply_updates(updates, Cache.Empty{}, 0n, rebuilt, reused)
        +cached : Nat <- IO.now()
        index : Mapping.Tree = Mapping.reuse(Mapping.Empty{}, chunks)
        indexed : Nat <- IO.now()
        IO.print("opening_finish entries_ms=" ++ Nat.show(Nat.sub(cached, start)) ++
          " index_ms=" ++ Nat.show(Nat.sub(indexed, cached)))
        return Cache.CachedScene{scene, cache, index, host, Nil{}}

def render_stages(document: D.Document) -> IO(Cache.CachedScene):
  match document:
    case D.Document{blocks, next, reparsed}:
      do IO<Cache.CachedScene>:
        start : Nat <- IO.now()
        rendered : Cache.Rendered = Cache.scan_tree(blocks, Cache.Empty{}, 0n, 0n, 0n)
        +scanned : Nat <- IO.now()
        result : Cache.CachedScene <- finish_stages(rendered)
        finished : Nat <- IO.now()
        IO.print("opening_cache scan_ms=" ++ Nat.show(Nat.sub(scanned, start)) ++
          " finish_ms=" ++ Nat.show(Nat.sub(finished, scanned)))
        return result

def sample(+size: Nat) -> IO(Unit):
  +text = Fixture.sample(size)
  do IO<Unit>:
    start : Nat <- IO.now()
    +document : D.Document = D.parse(text)
    parsed : Nat <- IO.now()
    result : Cache.CachedScene <- render_stages(document)
    rendered : Nat <- IO.now()
    report(document, result, start, parsed, rendered)

def choose(args: List<String>) -> IO(Unit):
  match args:
    case program <> "large" <> Nil{}:
      sample(1048576n)
    case program <> Nil{}:
      sample(102400n)
    case _:
      IO.die(Unit, 2, "Use no argument or large")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    choose(args)
