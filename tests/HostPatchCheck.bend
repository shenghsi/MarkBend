import Base
import ../src/BlockScene.bend as Scene
import ../src/BlockSceneCache.bend as Cache
import ../src/BlockIndex.bend as T
import ../src/TextPosition.bend as Position
import ./SessionViewCheck.bend as View

type Replayed is Data:
  Replayed{tree: T.Tree<Scene.HostChunk>, valid: Bool}

def width(chunk: Scene.HostChunk) -> Nat:
  match chunk:
    case Scene.HostChunk{id, fresh, runs}:
      +text = Scene.text(Scene.Scene{runs, Nil{}})
      Position.to_native(text, String.length(text))

def same(a: List<&2, Scene.HostChunk>, b: List<&2, Scene.HostChunk>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Scene.HostChunk{id, fresh, runs} <> rest Scene.HostChunk{other, flag, later} <> tail:
      Nat.is_eq(id, other) && View.same_runs(runs, later) && same(rest, tail)
    case _ _:
      False{}

def tail(+prefix: T.Tree<Scene.HostChunk>, middle: T.Split<Scene.HostChunk>,
  inserted: T.Tree<Scene.HostChunk>, start: Nat, length: Nat, bounded: Bool) -> Replayed:
  match middle:
    case T.Split{+removed, suffix}:
      Replayed{T.concat(Scene.HostChunk, prefix, T.concat(Scene.HostChunk, inserted, suffix)),
        bounded && Nat.is_eq(start, T.length(Scene.HostChunk, prefix)) &&
          Nat.is_eq(length, T.length(Scene.HostChunk, removed))}

def cut(cut: T.Split<Scene.HostChunk>, removed: Nat, inserted: T.Tree<Scene.HostChunk>,
  start: Nat, length: Nat, bounded: Bool) -> Replayed:
  match cut:
    case T.Split{+prefix, rest}:
      tail(prefix, T.split(Scene.HostChunk, rest, removed), inserted, start, length, bounded)

def one(patch: Scene.HostPatch, +tree: T.Tree<Scene.HostChunk>) -> Replayed:
  match patch:
    case Scene.HostPatch{+first, +removed, start, length, chunks}:
      cut(T.split(Scene.HostChunk, tree, first), removed,
        T.from_list(~Scene.HostChunk, ~width, chunks), start, length,
        Nat.is_le(first, T.count(Scene.HostChunk, tree)) &&
          Nat.is_le(removed, Nat.sub(T.count(Scene.HostChunk, tree), first)))

def combine(previous: Bool, next: Replayed) -> Replayed:
  match next:
    case Replayed{tree, valid}:
      Replayed{tree, previous && valid}

def replay(patches: List<&2, Scene.HostPatch>, prior: Replayed) -> Replayed:
  match patches prior:
    case Nil{} _:
      prior
    case patch <> rest Replayed{tree, valid}:
      replay(rest, combine(valid, one(patch, tree)))

def matches(replayed: Replayed, expected: List<&2, Scene.HostChunk>) -> Bool:
  match replayed:
    case Replayed{tree, valid}:
      valid && same(T.flatten(Scene.HostChunk, tree, Nil{}), expected)

def valid(before: Cache.CachedScene, after: Cache.CachedScene) -> Bool:
  match before after:
    case Cache.CachedScene{scene, cache, index, host, patches}
      Cache.CachedScene{later, other, final, chunks, edits}:
      matches(replay(edits, Replayed{T.from_list(~Scene.HostChunk, ~width,
        Cache.complete_host(index, Nil{})), True{}}), Cache.complete_host(final, Nil{}))

def transferred(patches: List<&2, Scene.HostPatch>) -> Nat:
  match patches:
    case Nil{}:
      0n
    case Scene.HostPatch{first, removed, start, length, chunks} <> rest:
      Nat.add(List.length(&2, Scene.HostChunk, chunks), transferred(rest))

def count(after: Cache.CachedScene) -> Nat:
  match after:
    case Cache.CachedScene{scene, cache, index, host, patches}:
      transferred(patches)

def sparse(after: Cache.CachedScene) -> Bool:
  match after:
    case Cache.CachedScene{scene, cache, index, Nil{}, patches}:
      True{}
    case _:
      False{}
