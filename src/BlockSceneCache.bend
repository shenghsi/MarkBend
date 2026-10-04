import Base
import ./BlockScene.bend as Scene
import ./Blocks.bend as Blocks
import ./Document.bend as D
import ./BlockIndex.bend as Index
import ./SceneIndex.bend as Mapping
import ./ListAppend.bend as Append

# Local scenes use block-relative source positions. Stable block identifiers
# permit reuse when an edit moves a block to a different document position.
type Entry is Data:
  Entry{id: Nat, start: Nat, end: Nat, scene: Scene.Scene, chunk: Mapping.Chunk}

type Trie is Data:
  Empty{}
  Node{item: Maybe<&2, Entry>, zero: Trie, one: Trie}

type Cache is Data:
  Cache{tree: Trie, count: Nat, rebuilt: Nat, reused: Nat}

type Rendered is Data:
  Rendered{scene: Scene.Scene, updates: List<&2, Entry>, rebuilt: Nat, reused: Nat,
    chunks: List<&2, Mapping.Chunk>, host: List<&2, Scene.HostChunk>}

type CachedScene is Data:
  CachedScene{scene: Scene.Scene, cache: Cache, index: Mapping.Tree,
    host: List<&2, Scene.HostChunk>, patches: List<&2, Scene.HostPatch>}

def empty() -> Cache:
  Cache{Empty{}, 0n, 0n, 0n}

def cache_tree(cache: Cache) -> Trie:
  match cache:
    case Cache{tree, count, rebuilt, reused}:
      tree

def cache(result: CachedScene) -> Cache:
  match result:
    case CachedScene{scene, cache, index, host, patches}:
      cache

def index(result: CachedScene) -> Mapping.Tree:
  match result:
    case CachedScene{scene, cache, index, host, patches}:
      index

def host_runs(chunks: List<&2, Scene.HostChunk>) -> List<&2, Scene.Run>:
  match chunks:
    case Nil{}:
      Nil{}
    case Scene.HostChunk{id, fresh, runs} <> rest:
      List.append(&2, Scene.Run, runs, host_runs(rest))

# Complete run lists are for reference checks. The live host uses block chunks.
def reference_scene(scene: Scene.Scene, host: List<&2, Scene.HostChunk>) -> Scene.Scene:
  match host:
    case Nil{}:
      scene
    case head <> rest:
      Scene.Scene{host_runs(head <> rest), Nil{}}

def scene(result: CachedScene) -> Scene.Scene:
  match result:
    case CachedScene{scene, cache, +index, host, patches}:
      Mapping.full_scene(Scene.Scene{Mapping.runs(index, Nil{}), Nil{}}, index)

def host_scene(result: CachedScene) -> Scene.Scene:
  match result:
    case CachedScene{scene, cache, index, host, patches}:
      Scene.Scene{Mapping.runs(index, Nil{}), Nil{}}

def lookup_branch(odd: Bool, zero: Unit -> Maybe<&2, Entry>, one: Unit -> Maybe<&2, Entry>)
  -> Maybe<&2, Entry>:
  match odd:
    case False{}:
      zero(Unit{})
    case True{}:
      one(Unit{})

def lookup(tree: Trie, +key: Nat) -> Maybe<&2, Entry>:
  match tree key:
    case Empty{} _:
      None{}
    case Node{item, zero, one} 0n:
      item
    case Node{item, zero, one} _:
      lookup_branch(Nat.is_eq(Nat.mod(key, 2n), 1n),
        _ => lookup(zero, Nat.div(key, 2n)), _ => lookup(one, Nat.div(key, 2n)))

def store_branch(odd: Bool, zero: Unit -> Trie, one: Unit -> Trie) -> Trie:
  match odd:
    case False{}:
      zero(Unit{})
    case True{}:
      one(Unit{})

def store(fuel: Nat, tree: Trie, +key: Nat, +entry: Entry) -> Trie:
  match fuel tree key:
    case 0n _ _:
      tree
    case 1n+rest Empty{} 0n:
      Node{Some{entry}, Empty{}, Empty{}}
    case 1n+rest Node{item, zero, one} 0n:
      Node{Some{entry}, zero, one}
    case 1n+ +rest Empty{} _:
      store_branch(Nat.is_eq(Nat.mod(key, 2n), 1n),
        _ => Node{None{}, store(rest, Empty{}, Nat.div(key, 2n), entry), Empty{}},
        _ => Node{None{}, Empty{}, store(rest, Empty{}, Nat.div(key, 2n), entry)})
    case 1n+ +rest Node{+item, +zero, +one} _:
      store_branch(Nat.is_eq(Nat.mod(key, 2n), 1n),
        _ => Node{item, store(rest, zero, Nat.div(key, 2n), entry), one},
        _ => Node{item, zero, store(rest, one, Nat.div(key, 2n), entry)})

def entry_id(entry: Entry) -> Nat:
  match entry:
    case Entry{id, start, end, scene, chunk}:
      id

def added(found: Maybe<&2, Entry>) -> Nat:
  match found:
    case None{}:
      1n
    case Some{entry}:
      0n

def apply_updates_sequential(updates: List<&2, Entry>, +tree: Trie, count: Nat,
  rebuilt: Nat, reused: Nat) -> Cache:
  match updates:
    case Nil{}:
      Cache{tree, count, rebuilt, reused}
    case +entry <> rest:
      +key = entry_id(entry)
      +extra = added(lookup(tree, key))
      apply_updates_sequential(rest, store(1n+key, tree, key, entry), Nat.add(count, extra), rebuilt, reused)

type KeyedEntry is Data:
  KeyedEntry{key: Nat, entry: Entry}

type Partition is Data:
  Partition{item: Maybe<&2, Entry>, zero: List<&2, KeyedEntry>, one: List<&2, KeyedEntry>}

type BuiltTrie is Data:
  BuiltTrie{tree: Trie, count: Nat}

type KeyedSeed is Data:
  KeyedSeed{entries: List<&2, KeyedEntry>, maximum: Nat}

def keyed_acc(entries: List<&2, Entry>, keys: List<&2, KeyedEntry>, maximum: Nat) -> KeyedSeed:
  match entries:
    case Nil{}:
      KeyedSeed{List.reverse(&2, KeyedEntry, keys), maximum}
    case +entry <> rest:
      +key = entry_id(entry)
      keyed_acc(rest, KeyedEntry{key, entry} <> keys, Nat.max(key, maximum))

def keyed(entries: List<&2, Entry>) -> KeyedSeed:
  keyed_acc(entries, Nil{}, 0n)

def partition_side(odd: Bool, key: Nat, entry: Entry, parts: Partition) -> Partition:
  match odd parts:
    case False{} Partition{item, zero, one}:
      Partition{item, KeyedEntry{key, entry} <> zero, one}
    case True{} Partition{item, zero, one}:
      Partition{item, zero, KeyedEntry{key, entry} <> one}

def partition_entry(+key: Nat, entry: Entry, parts: Partition) -> Partition:
  match key parts:
    case 0n Partition{item, zero, one}:
      Partition{Some{entry}, zero, one}
    case _ _:
      partition_side(Nat.is_eq(Nat.mod(key, 2n), 1n), Nat.div(key, 2n), entry, parts)

def partition_done(parts: Partition) -> Partition:
  match parts:
    case Partition{item, zero, one}:
      Partition{item, List.reverse(&2, KeyedEntry, zero), List.reverse(&2, KeyedEntry, one)}

def partition_acc(entries: List<&2, KeyedEntry>, parts: Partition) -> Partition:
  match entries:
    case Nil{}:
      partition_done(parts)
    case KeyedEntry{key, entry} <> rest:
      partition_acc(rest, partition_entry(key, entry, parts))

def partition(entries: List<&2, KeyedEntry>) -> Partition:
  partition_acc(entries, Partition{None{}, Nil{}, Nil{}})

def item_count(item: Maybe<&2, Entry>) -> Nat:
  match item:
    case None{}:
      0n
    case Some{entry}:
      1n

def built_node(+item: Maybe<&2, Entry>, left: BuiltTrie, right: BuiltTrie) -> BuiltTrie:
  match left right:
    case BuiltTrie{zero, a} BuiltTrie{one, b}:
      BuiltTrie{Node{item, zero, one}, Nat.add(item_count(item), Nat.add(a, b))}

def bulk_pair(parallel: Bool, item: Maybe<&2, Entry>, left: Unit -> BuiltTrie,
  right: Unit -> BuiltTrie) -> BuiltTrie:
  match parallel:
    case False{}:
      built_node(item, left(Unit{}), right(Unit{}))
    case True{}:
      a b = left(Unit{}) right(Unit{})
      built_node(item, a, b)

def bulk_trie(fuel: Nat, parts: Partition) -> BuiltTrie:
  match fuel parts:
    case 0n _:
      BuiltTrie{Empty{}, 0n}
    case _ Partition{None{}, Nil{}, Nil{}}:
      BuiltTrie{Empty{}, 0n}
    case 1n+ +rest Partition{item, +zero, +one}:
      bulk_pair(Nat.is_ge(Nat.add(Index.list_count(KeyedEntry, zero, 0n),
        Index.list_count(KeyedEntry, one, 0n)), 8192n), item,
        _ => bulk_trie(rest, partition(zero)), _ => bulk_trie(rest, partition(one)))

def seeded_trie(seed: KeyedSeed) -> BuiltTrie:
  match seed:
    case KeyedSeed{entries, maximum}:
      bulk_trie(1n+maximum, partition(entries))

def bulk_cache(built: BuiltTrie, count: Nat, rebuilt: Nat, reused: Nat) -> Cache:
  match built:
    case BuiltTrie{tree, added}:
      Cache{tree, Nat.add(count, added), rebuilt, reused}

def apply_updates_choice(tree: Trie, bulk: Bool, updates: List<&2, Entry>,
  count: Nat, rebuilt: Nat, reused: Nat) -> Cache:
  match tree bulk:
    case Empty{} True{}:
      bulk_cache(seeded_trie(keyed(updates)), count, rebuilt, reused)
    case _ _:
      apply_updates_sequential(updates, tree, count, rebuilt, reused)

def apply_updates(updates: List<&2, Entry>, tree: Trie, count: Nat,
  +rebuilt: Nat, reused: Nat) -> Cache:
  apply_updates_choice(tree, Nat.is_ge(rebuilt, 8192n), updates, count, rebuilt, reused)

def shift(scene: Scene.Scene, offset: Nat) -> Scene.Scene:
  match scene:
    case Scene.Scene{runs, points}:
      Scene.Scene{runs, Scene.offset_points(points, offset)}

def join_runs(a: Scene.Scene, b: Scene.Scene) -> Scene.Scene:
  match a b:
    case Scene.Scene{runs, points} Scene.Scene{later, other_points}:
      Scene.Scene{List.append(&2, Scene.Run, runs, later), Nil{}}

def host_chunk(scene: Scene.Scene, chunk: Mapping.Chunk, fresh: Bool) -> Scene.HostChunk:
  match scene chunk:
    case Scene.Scene{runs, points} Mapping.Chunk{visible, other_points, source, native, last, id, start, end, saved_runs}:
      Scene.HostChunk{id, fresh, runs}

def push(+scene: Scene.Scene, +chunk: Mapping.Chunk, pending: Maybe<&2, Entry>, reused: Nat,
  tail: Rendered, offset: Nat) -> Rendered:
  match pending tail:
    case None{} Rendered{later, updates, rebuilt, kept, chunks, host}:
      Rendered{Scene.Scene{Nil{}, Nil{}}, updates, rebuilt, Nat.add(kept, reused),
        chunk <> chunks, host_chunk(scene, chunk, False{}) <> host}
    case Some{entry} Rendered{later, updates, rebuilt, kept, chunks, host}:
      Rendered{Scene.Scene{Nil{}, Nil{}}, entry <> updates, 1n+rebuilt, kept,
        chunk <> chunks, host_chunk(scene, chunk, True{}) <> host}

def source_size(piece: Blocks.Piece) -> Nat:
  match piece:
    case Blocks.Piece{kind, source}:
      String.length(source)

def fresh(+id: Nat, +piece: Blocks.Piece, +start: Nat, +end: Nat,
  tail: Rendered, offset: Nat) -> Rendered:
  +scene = Scene.piece(piece, start, end, 0n)
  +chunk = Mapping.chunk(scene, source_size(piece), id, start, end)
  push(scene, chunk, Some{Entry{id, start, end, scene, chunk}}, 0n, tail, offset)

def choose(hit: Bool, scene: Scene.Scene, chunk: Mapping.Chunk, later: Unit -> Rendered,
  tail: Rendered, offset: Nat) -> Rendered:
  match hit:
    case True{}:
      push(scene, chunk, None{}, 1n, tail, offset)
    case False{}:
      later(Unit{})

def cached(found: Maybe<&2, Entry>, id: Nat, piece: Blocks.Piece, +start: Nat,
  +end: Nat, +tail: Rendered, +offset: Nat) -> Rendered:
  match found:
    case None{}:
      fresh(id, piece, start, end, tail, offset)
    case Some{Entry{old_id, a, b, scene, chunk}}:
      choose(Nat.is_eq(start, a) && Nat.is_eq(end, b), scene, chunk,
        _ => fresh(id, piece, start, end, tail, offset), tail, offset)

def selected(active: Bool, +size: Nat, start: Nat, end: Nat, +offset: Nat) -> Nat & Nat:
  match active:
    case False{}:
      (1n+size, 1n+size)
    case True{}:
      (Nat.min(size, Nat.sub(start, offset)), Nat.min(size, Nat.sub(end, offset)))

def local(selection: Nat & Nat, found: Maybe<&2, Entry>, id: Nat, piece: Blocks.Piece,
  tail: Rendered, offset: Nat) -> Rendered:
  match selection:
    case (start, end):
      cached(found, id, piece, start, end, tail, offset)

def reverse_rendered(value: Rendered) -> Rendered:
  match value:
    case Rendered{scene, updates, rebuilt, reused, chunks, host}:
      Rendered{scene, List.reverse(&2, Entry, updates), rebuilt, reused,
        List.reverse(&2, Mapping.Chunk, chunks), List.reverse(&2, Scene.HostChunk, host)}

def scan_loop(blocks: List<&2, D.Block>, +tree: Trie, +start: Nat, +end: Nat,
  +offset: Nat, reversed: Rendered) -> Rendered:
  match blocks:
    case Nil{}:
      reverse_rendered(reversed)
    case D.Block{+id, kind, +source} <> rest:
      +size = String.length(source)
      +finish = Nat.add(offset, size)
      +active = Nat.is_le(Nat.min(start, end), finish) && Nat.is_le(offset, Nat.max(start, end))
      scan_loop(rest, tree, start, end, finish,
        local(selected(active, size, start, end, offset), lookup(tree, id), id,
          Blocks.Piece{kind, source}, reversed, offset))

def scan(blocks: List<&2, D.Block>, tree: Trie, start: Nat, end: Nat,
  offset: Nat) -> Rendered:
  scan_loop(blocks, tree, start, end, offset,
    Rendered{Scene.Scene{Nil{}, Nil{}}, Nil{}, 0n, 0n, Nil{}, Nil{}})

def join_rendered(left: Rendered, right: Rendered) -> Rendered:
  match left right:
    case Rendered{scene, updates, rebuilt, reused, chunks, host}
      Rendered{other_scene, other_updates, other_rebuilt, other_reused, other_chunks, other_host}:
      Rendered{Scene.Scene{Nil{}, Nil{}}, Append.append(&2, Entry, updates, other_updates),
        Nat.add(rebuilt, other_rebuilt), Nat.add(reused, other_reused),
        Append.append(&2, Mapping.Chunk, chunks, other_chunks),
        Append.append(&2, Scene.HostChunk, host, other_host)}

def scan_tree_branch(blocks: Index.Tree<D.Block>, parallel: Bool, +tree: Trie, +start: Nat, +end: Nat,
  +offset: Nat) -> Rendered:
  match blocks parallel:
    case Index.Branch{+left, +right, length, count, height} True{}:
      a b = scan_tree_branch(left, Nat.is_ge(Index.count(D.Block, left), 8192n), tree, start, end, offset)
        scan_tree_branch(right, Nat.is_ge(Index.count(D.Block, right), 8192n), tree, start, end,
          Nat.add(offset, Index.length(D.Block, left)))
      join_rendered(a, b)
    case _ _:
      scan(Index.flatten(D.Block, blocks, Nil{}), tree, start, end, offset)

def scan_tree(+blocks: Index.Tree<D.Block>, tree: Trie, start: Nat, end: Nat,
  offset: Nat) -> Rendered:
  scan_tree_branch(blocks, Nat.is_ge(Index.count(D.Block, blocks), 8192n), tree, start, end, offset)

def trimmed(over: Bool, cache: Cache) -> Cache:
  match over:
    case True{}:
      empty()
    case False{}:
      cache

def finished(rendered: Rendered, tree: Trie, count: Nat, prior: Mapping.Tree) -> CachedScene:
  match rendered:
    case Rendered{scene, updates, rebuilt, reused, chunks, host}:
      CachedScene{scene, apply_updates(updates, tree, count, rebuilt, reused), Mapping.reuse(prior, chunks), host, Nil{}}

def render_blocks(blocks: Index.Tree<D.Block>, start: Nat, end: Nat, cache: Cache,
  prior: Mapping.Tree) -> CachedScene:
  match cache:
    case Cache{+tree, count, rebuilt, reused}:
      finished(scan_tree(blocks, tree, start, end, 0n), tree, count, prior)

def render_with_index(document: D.Document, start: Nat, end: Nat, cache: Cache,
  prior: Mapping.Tree) -> CachedScene:
  match document cache:
    case D.Document{+blocks, next, reparsed} Cache{tree, +count, rebuilt, reused}:
      render_blocks(blocks, start, end,
        trimmed(Nat.is_gt(count, Nat.mul(2n, Index.count(D.Block, blocks))),
          Cache{tree, count, rebuilt, reused}), prior)

def render(document: D.Document, start: Nat, end: Nat, cache: Cache) -> CachedScene:
  render_with_index(document, start, end, cache, Mapping.Empty{})

type Refresh is Data:
  Refresh{cache: Cache, index: Mapping.Tree, patches: List<&2, Scene.HostPatch>, visited: Nat}

type RefreshResult is Data:
  RefreshResult{result: CachedScene, visited: Nat}

def result(value: RefreshResult) -> CachedScene:
  match value:
    case RefreshResult{result, visited}:
      result

def visited(value: RefreshResult) -> Nat:
  match value:
    case RefreshResult{result, visited}:
      visited

def selected_blocks(+blocks: Index.Tree<D.Block>, +start: Nat, +end: Nat) -> Nat & Nat:
  (Index.rank(D.Block, blocks, Nat.sub(Nat.min(start, end), 1n), 0n),
    Nat.min(Index.count(D.Block, blocks), 1n+Index.rank(D.Block, blocks, Nat.max(start, end), 0n)))

def old_selected_blocks(+tree: Mapping.Tree, +start: Nat, +end: Nat) -> Nat & Nat:
  (Mapping.rank(tree, Nat.sub(Nat.min(start, end), 1n), 0n),
    Nat.min(Mapping.count(tree), 1n+Mapping.rank(tree, Nat.max(start, end), 0n)))

def translated_rank(before: Bool, after: Bool, at: Nat, first: Nat,
  removed: Nat, added: Nat, inside: Nat) -> Nat:
  match before after:
    case True{} _:
      at
    case _ True{}:
      Nat.add(Nat.sub(at, removed), added)
    case _ _:
      inside

def translated_selection(range: Nat & Nat, +first: Nat, +removed: Nat, +added: Nat) -> Nat & Nat:
  match range:
    case (+a, +b):
      (translated_rank(Nat.is_le(a, first), Nat.is_ge(a, Nat.add(first, removed)),
        a, first, removed, added, first),
        translated_rank(Nat.is_le(b, first), Nat.is_ge(b, Nat.add(first, removed)),
          b, first, removed, added, Nat.add(first, added)))

def patch_tail(first: Nat, removed: Nat, start: Nat, tail: Mapping.Split,
  chunks: List<&2, Scene.HostChunk>) -> Scene.HostPatch:
  match tail:
    case Mapping.Split{middle, suffix}:
      Scene.HostPatch{first, removed, start, Mapping.native_length(middle), chunks}

def patch_cut(+first: Nat, +removed: Nat, cut: Mapping.Split,
  chunks: List<&2, Scene.HostChunk>) -> Scene.HostPatch:
  match cut:
    case Mapping.Split{prefix, tail}:
      patch_tail(first, removed, Mapping.native_length(prefix), Mapping.split(tail, removed), chunks)

def region_patches(changed: Bool, prior: Mapping.Tree, +first: Nat, +removed: Nat,
  host: List<&2, Scene.HostChunk>, patches: List<&2, Scene.HostPatch>) -> List<&2, Scene.HostPatch>:
  match changed:
    case True{}:
      patch_cut(first, removed, Mapping.split(prior, first), host) <> patches
    case False{}:
      patches

def refreshed_region(rendered: Rendered, cache: Cache, +prior: Mapping.Tree,
  patches: List<&2, Scene.HostPatch>, visited: Nat, +first: Nat, +removed: Nat) -> Refresh:
  match rendered cache:
    case Rendered{scene, updates, +rebuilt, reused, +chunks, host}
      Cache{tree, count, previous, kept}:
      Refresh{apply_updates(updates, tree, count, Nat.add(previous, rebuilt), 0n),
        Mapping.splice(prior, first, removed, chunks),
        region_patches(Nat.is_gt(rebuilt, 0n) ||
          Nat.is_ne(removed, List.length(&2, Mapping.Chunk, chunks)), prior, first, removed, host, patches),
        Nat.add(visited, List.length(&2, Mapping.Chunk, chunks))}

def scan_region(region: Index.Split<D.Block>, tree: Trie, start: Nat, end: Nat,
  offset: Nat) -> Rendered:
  match region:
    case Index.Split{blocks, suffix}:
      scan(Index.flatten(D.Block, blocks, Nil{}), tree, start, end, offset)

def refresh_cut(cut: Index.Split<D.Block>, +start: Nat, +end: Nat,
  first: Nat, removed: Nat, amount: Nat, prior: Refresh) -> Refresh:
  match cut prior:
    case Index.Split{prefix, tail} Refresh{Cache{+tree, +count, +rebuilt, +reused}, index, patches, visited}:
      refreshed_region(scan_region(Index.split(D.Block, tail, amount), tree, start, end,
        Index.length(D.Block, prefix)), Cache{tree, count, rebuilt, reused},
        index, patches, visited, first, removed)

def refresh_range(+blocks: Index.Tree<D.Block>, start: Nat, end: Nat, +first: Nat,
  removed: Nat, amount: Nat, prior: Refresh) -> Refresh:
  refresh_cut(Index.split(D.Block, blocks, first), start, end, first, removed, amount, prior)

def refresh_current(blocks: Index.Tree<D.Block>, start: Nat, end: Nat,
  current: Nat & Nat, prior: Refresh) -> Refresh:
  match current:
    case (+c, +d):
      refresh_range(blocks, start, end, c, Nat.sub(d, c), Nat.sub(d, c), prior)

def refresh_selections(+blocks: Index.Tree<D.Block>, +start: Nat, +end: Nat,
  old: Nat & Nat, current: Nat & Nat, prior: Refresh) -> Refresh:
  match old:
    case (+a, +b):
      refresh_current(blocks, start, end, current,
        refresh_range(blocks, start, end, a, Nat.sub(b, a), Nat.sub(b, a), prior))

# Complete presentation is for opening, history, and explicit refresh requests.
def complete_host(tree: Mapping.Tree, tail: List<&2, Scene.HostChunk>) -> List<&2, Scene.HostChunk>:
  match tree:
    case Mapping.Empty{}:
      tail
    case Mapping.Leaf{Mapping.Chunk{visible, points, source, native, last, +id, start, end, runs}}:
      Scene.HostChunk{id, True{}, runs} <> tail
    case Mapping.Branch{left, right, source, native, last, count, height}:
      complete_host(left, complete_host(right, tail))

def finish_refresh(prior: Refresh) -> RefreshResult:
  match prior:
    case Refresh{Cache{tree, count, +rebuilt, reused}, +index, patches, visited}:
      RefreshResult{CachedScene{Scene.Scene{Nil{}, Nil{}},
        Cache{tree, count, rebuilt, Nat.sub(Mapping.count(index), rebuilt)}, index,
        Nil{}, List.reverse(&2, Scene.HostPatch, patches)}, visited}

def change_regions(+blocks: Index.Tree<D.Block>, +start: Nat, +end: Nat,
  +first: Nat, +removed: Nat, +added: Nat, old_start: Nat, old_end: Nat,
  cache: Cache, +prior: Mapping.Tree) -> RefreshResult:
  finish_refresh(refresh_selections(blocks, start, end,
    translated_selection(old_selected_blocks(prior, old_start, old_end), first, removed, added),
    selected_blocks(blocks, start, end),
    refresh_range(blocks, start, end, first, removed, added, Refresh{cache, prior, Nil{}, 0n})))

def render_change_counted(change: D.Change, start: Nat, end: Nat, old_start: Nat, old_end: Nat,
  cache: Cache, prior: Mapping.Tree) -> RefreshResult:
  match change cache:
    case D.Change{D.Document{+blocks, next, reparsed}, first, removed, added}
      Cache{tree, +count, rebuilt, reused}:
      change_regions(blocks, start, end, first, removed, added, old_start, old_end,
        trimmed(Nat.is_gt(count, Nat.mul(2n, Index.count(D.Block, blocks))),
          Cache{tree, count, 0n, 0n}), prior)

def render_change(change: D.Change, start: Nat, end: Nat, old_start: Nat, old_end: Nat,
  cache: Cache, prior: Mapping.Tree) -> CachedScene:
  result(render_change_counted(change, start, end, old_start, old_end, cache, prior))
