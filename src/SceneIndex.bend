import Base
import ./BlockScene.bend as Scene
import ./BlockIndex.bend as Index
import ./CursorMap.bend as Cursor
import ./TextPosition.bend as Position

type Chunk is Data:
  Chunk{visible: String, points: List<&2, Nat>, source_length: Nat,
    native_length: Nat, last_point: Nat, id: Nat, start: Nat, end: Nat,
    runs: List<&2, Scene.Run>}

type Tree is Data:
  Empty{}
  Leaf{chunk: Chunk}
  Branch{left: Tree, right: Tree, source_length: Nat, native_length: Nat, last_point: Nat,
    count: Nat, height: Nat}

type Split is Data:
  Split{left: Tree, right: Tree}

type Updated is Data:
  Updated{tree: Tree, rest: List<&2, Chunk>, changed: Bool}

def scene_runs(scene: Scene.Scene) -> List<&2, Scene.Run>:
  match scene:
    case Scene.Scene{runs, points}:
      runs

def chunk(+scene: Scene.Scene, source_length: Nat, id: Nat, start: Nat, end: Nat) -> Chunk:
  +visible = Scene.text(scene)
  +points = Scene.points(scene)
  +scalars = String.length(visible)
  Chunk{visible, points, source_length, Position.to_native(visible, scalars),
    Cursor.to_source(points, Nat.sub(scalars, 1n)), id, start, end, scene_runs(scene)}

def chunk_native(chunk: Chunk) -> Nat:
  match chunk:
    case Chunk{visible, points, source, native, last, id, start, end, runs}:
      native

def source_length(tree: Tree) -> Nat:
  match tree:
    case Empty{}:
      0n
    case Leaf{Chunk{visible, points, source, native, last, id, start, end, runs}}:
      source
    case Branch{left, right, source, native, last, count, height}:
      source

def native_length(tree: Tree) -> Nat:
  match tree:
    case Empty{}:
      0n
    case Leaf{Chunk{visible, points, source, native, last, id, start, end, runs}}:
      native
    case Branch{left, right, source, native, last, count, height}:
      native

def last_point(tree: Tree) -> Nat:
  match tree:
    case Empty{}:
      0n
    case Leaf{Chunk{visible, points, source, native, last, id, start, end, runs}}:
      last
    case Branch{left, right, source, native, last, count, height}:
      last

def count(tree: Tree) -> Nat:
  match tree:
    case Empty{}:
      0n
    case Leaf{chunk}:
      1n
    case Branch{left, right, source, native, last, count, height}:
      count

def height(tree: Tree) -> Nat:
  match tree:
    case Empty{}:
      0n
    case Leaf{chunk}:
      1n
    case Branch{left, right, source, native, last, count, height}:
      height

def last_choice(right_visible: Bool, left: Nat, right: Nat) -> Nat:
  match right_visible:
    case True{}:
      right
    case False{}:
      left

def node(+left: Tree, +right: Tree) -> Tree:
  match left right:
    case Empty{} _:
      right
    case _ Empty{}:
      left
    case _ _:
      +left_source = source_length(left)
      Branch{left, right, Nat.add(left_source, source_length(right)),
        Nat.add(native_length(left), native_length(right)),
        last_choice(Nat.is_gt(native_length(right), 0n), last_point(left),
          Nat.add(left_source, last_point(right))), Nat.add(count(left), count(right)),
        1n+Nat.max(height(left), height(right))}

def rotate_left_inner(left: Tree, +middle: Tree, right: Tree) -> Tree:
  match middle:
    case Branch{a, b, source, native, last, count, height}:
      node(node(left, a), node(b, right))
    case _:
      node(node(left, middle), right)

def rotate_choice(single: Bool, direct: Unit -> Tree, double: Unit -> Tree) -> Tree:
  match single:
    case True{}:
      direct(Unit{})
    case False{}:
      double(Unit{})

def rotate_left(+left: Tree, +right: Tree) -> Tree:
  match right:
    case Branch{+a, +b, source, native, last, count, h}:
      rotate_choice(Nat.is_le(height(a), height(b)),
        _ => node(node(left, a), b), _ => rotate_left_inner(left, a, b))
    case _:
      node(left, right)

def rotate_right_inner(left: Tree, +middle: Tree, right: Tree) -> Tree:
  match middle:
    case Branch{a, b, source, native, last, count, height}:
      node(node(left, a), node(b, right))
    case _:
      node(left, node(middle, right))

def rotate_right(+left: Tree, +right: Tree) -> Tree:
  match left:
    case Branch{+a, +b, source, native, last, count, h}:
      rotate_choice(Nat.is_ge(height(a), height(b)),
        _ => node(a, node(b, right)), _ => rotate_right_inner(a, b, right))
    case _:
      node(left, right)

def join_choice(left_tall: Bool, right_tall: Bool, normal: Unit -> Tree,
  left: Unit -> Tree, right: Unit -> Tree) -> Tree:
  match left_tall right_tall:
    case True{} _:
      left(Unit{})
    case _ True{}:
      right(Unit{})
    case _ _:
      normal(Unit{})

def balance(+left: Tree, +right: Tree) -> Tree:
  join_choice(Nat.is_gt(height(left), 1n+height(right)),
    Nat.is_gt(height(right), 1n+height(left)), _ => node(left, right),
    _ => rotate_right(left, right), _ => rotate_left(left, right))

def concat(+left: Tree, +right: Tree) -> Tree:
  match left right:
    case Empty{} _:
      right
    case _ Empty{}:
      left
    case Leaf{chunk} Leaf{other}:
      node(left, right)
    case Branch{+a, +b, source, native, last, count, +h} Leaf{chunk}:
      join_choice(Nat.is_gt(h, 2n), False{}, _ => node(left, right),
        _ => balance(a, concat(b, right)), _ => node(left, right))
    case Leaf{chunk} Branch{+a, +b, source, native, last, count, +h}:
      join_choice(False{}, Nat.is_gt(h, 2n), _ => node(left, right),
        _ => node(left, right), _ => balance(concat(left, a), b))
    case Branch{+a, +b, source, native, last, count, +h}
      Branch{+c, +d, other_source, other_native, other_last, other_count, +k}:
      join_choice(Nat.is_gt(h, 1n+k), Nat.is_gt(k, 1n+h), _ => node(left, right),
        _ => balance(a, concat(b, right)), _ => balance(concat(left, c), d))

def split_left(result: Split, other: Tree) -> Split:
  match result:
    case Split{left, right}:
      Split{left, concat(right, other)}

def split_right(other: Tree, result: Split) -> Split:
  match result:
    case Split{left, right}:
      Split{concat(other, left), right}

def split_choice(zero: Bool, all: Bool, tree: Tree, inside: Unit -> Split) -> Split:
  match zero all:
    case True{} _:
      Split{Empty{}, tree}
    case _ True{}:
      Split{tree, Empty{}}
    case _ _:
      inside(Unit{})

def split_branch(go_left: Bool, left: Unit -> Split, right: Unit -> Split) -> Split:
  match go_left:
    case True{}:
      left(Unit{})
    case False{}:
      right(Unit{})

def split(+tree: Tree, +at: Nat) -> Split:
  match tree:
    case Empty{}:
      Split{Empty{}, Empty{}}
    case Leaf{chunk}:
      split_choice(Nat.is_eq(at, 0n), True{}, tree, _ => Split{Empty{}, Empty{}})
    case Branch{+left, +right, source, native, last, +items, height}:
      +left_count = count(left)
      split_choice(Nat.is_eq(at, 0n), Nat.is_ge(at, items), tree,
        _ => split_branch(Nat.is_lt(at, left_count),
          _ => split_left(split(left, at), right),
          _ => split_right(left, split(right, Nat.sub(at, left_count)))))

def splice_tail(prefix: Tree, removed: Split, inserted: Tree) -> Tree:
  match removed:
    case Split{discarded, suffix}:
      concat(prefix, concat(inserted, suffix))

def splice_cut(cut: Split, removed: Nat, inserted: Tree) -> Tree:
  match cut:
    case Split{prefix, tail}:
      splice_tail(prefix, split(tail, removed), inserted)

def build_pair(parallel: Bool, left: Unit -> Tree, right: Unit -> Tree) -> Tree:
  match parallel:
    case False{}:
      node(left(Unit{}), right(Unit{}))
    case True{}:
      a b = left(Unit{}) right(Unit{})
      node(a, b)

def from_tree(tree: Index.Tree<Chunk>) -> Tree:
  match tree:
    case Index.Empty{}:
      Empty{}
    case Index.Leaf{chunk, length}:
      Leaf{chunk}
    case Index.Branch{left, right, length, count, height}:
      build_pair(Nat.is_ge(count, 8192n), _ => from_tree(left), _ => from_tree(right))

def build(chunks: List<&2, Chunk>) -> Tree:
  from_tree(Index.from_list(~Chunk, ~chunk_native, chunks))

# Positions and removal counts are block counts. Only affected paths are rebuilt.
def splice(tree: Tree, first: Nat, removed: Nat, chunks: List<&2, Chunk>) -> Tree:
  splice_cut(split(tree, first), removed, build(chunks))

def same_chunk(a: Chunk, b: Chunk) -> Bool:
  match a b:
    case Chunk{visible, points, source, native, last, id, start, end, runs}
      Chunk{other, later, size, units, final, other_id, a, b, other_runs}:
      Nat.is_eq(id, other_id) && Nat.is_eq(start, a) && Nat.is_eq(end, b)

def update_leaf(same: Bool, saved: Tree, chunk: Chunk, rest: List<&2, Chunk>) -> Updated:
  match same:
    case True{}:
      Updated{saved, rest, False{}}
    case False{}:
      Updated{Leaf{chunk}, rest, True{}}

def update_branch(same: Bool, saved: Tree, left: Tree, right: Tree,
  rest: List<&2, Chunk>) -> Updated:
  match same:
    case True{}:
      Updated{saved, rest, False{}}
    case False{}:
      Updated{node(left, right), rest, True{}}

def update_right(saved: Tree, left: Tree, left_changed: Bool, right: Updated) -> Updated:
  match right:
    case Updated{tree, rest, changed}:
      update_branch(Bool.not(left_changed) && Bool.not(changed), saved, left, tree, rest)

def update_left(saved: Tree, left: Updated, later: List<&2, Chunk> -> Updated) -> Updated:
  match left:
    case Updated{tree, rest, changed}:
      update_right(saved, tree, changed, later(rest))

def update(+tree: Tree, chunks: List<&2, Chunk>) -> Updated:
  match tree chunks:
    case Empty{} _:
      Updated{tree, chunks, False{}}
    case Leaf{old} Nil{}:
      Updated{Empty{}, Nil{}, True{}}
    case Leaf{old} +chunk <> rest:
      update_leaf(same_chunk(old, chunk), tree, chunk, rest)
    case Branch{left, right, source, native, last, count, height} _:
      update_left(tree, update(left, chunks), rest => update(right, rest))

def updated_tree(result: Updated) -> Tree:
  match result:
    case Updated{tree, rest, changed}:
      tree

def reuse_choice(same_count: Bool, old: Tree, chunks: List<&2, Chunk>) -> Tree:
  match same_count:
    case True{}:
      updated_tree(update(old, chunks))
    case False{}:
      build(chunks)

# Equal block counts retain the old balanced shape and share unchanged branches.
# A different count uses a new balanced build. Identifiers are valid only within
# one document history; callers reset the index on raw replacement and undo.
def reuse(+old: Tree, +chunks: List<&2, Chunk>) -> Tree:
  reuse_choice(Nat.is_eq(count(old), Index.list_count(Chunk, chunks, 0n)), old, chunks)

def choose(go_left: Bool, left: Unit -> Nat, right: Unit -> Nat) -> Nat:
  match go_left:
    case True{}:
      left(Unit{})
    case False{}:
      right(Unit{})

# Source ranks count blocks and use cached lengths. Selection ranges include
# both blocks at a shared source boundary.
def rank_leaf(hit: Bool, at: Nat) -> Nat:
  match hit:
    case True{}:
      at
    case False{}:
      1n+at

def rank(tree: Tree, +source: Nat, +at: Nat) -> Nat:
  match tree:
    case Empty{}:
      at
    case Leaf{Chunk{visible, points, length, native, last, id, start, end, runs}}:
      rank_leaf(Nat.is_lt(source, length), at)
    case Branch{+left, right, length, native, last, total, height}:
      +width = source_length(left)
      +items = count(left)
      choose(Nat.is_lt(source, width), _ => rank(left, source, at),
        _ => rank(right, Nat.sub(source, width), Nat.add(at, items)))

# A visible block boundary belongs to the next block. Zero-width blocks are
# skipped. The final boundary maps to the complete source end.
def choose_source(go_left: Bool, left: (Unit -> Nat) -> Nat,
  right: (Unit -> Nat) -> Nat, finish: Unit -> Nat) -> Nat:
  match go_left:
    case True{}:
      left(finish)
    case False{}:
      right(finish)

def chunk_source(chunk: Chunk, native: Nat, +offset: Nat, finish: Unit -> Nat) -> Nat:
  match chunk:
    case Chunk{+visible, points, source, size, last, id, start, end, runs}:
      +scalar = Position.to_scalar(visible, native)
      choose(Nat.is_lt(scalar, String.length(visible)),
        _ => Nat.add(offset, Cursor.to_source(points, scalar)), finish)

def source_scan(tree: Tree, +native: Nat, +offset: Nat, finish: Unit -> Nat) -> Nat:
  match tree:
    case Empty{}:
      finish(Unit{})
    case Leaf{chunk}:
      chunk_source(chunk, native, offset, finish)
    case Branch{+left, +right, source, size, last, count, height}:
      +left_native = native_length(left)
      +left_source = source_length(left)
      choose_source(Nat.is_lt(native, left_native),
        end => source_scan(left, native, offset,
          _ => source_scan(right, 0n, Nat.add(offset, left_source), end)),
        end => source_scan(right, Nat.sub(native, left_native), Nat.add(offset, left_source), end),
        finish)

def to_source(+tree: Tree, native: Nat) -> Nat:
  +finish = source_length(tree)
  source_scan(tree, native, 0n, _ => finish)

# Use the last non-final point of the left subtree. Its final point is removed
# when scenes are joined, so source length alone cannot choose this branch.
def native_scan(tree: Tree, +source: Nat, +offset: Nat) -> Nat:
  match tree:
    case Empty{}:
      offset
    case Leaf{Chunk{visible, points, length, native, last, id, start, end, runs}}:
      Nat.add(offset, Position.to_native(visible, Cursor.to_view(points, source)))
    case Branch{+left, right, length, native, last, count, height}:
      +left_source = source_length(left)
      +left_native = native_length(left)
      +last = last_point(left)
      choose(Nat.is_gt(left_native, 0n) && Nat.is_le(source, last),
        _ => native_scan(left, source, offset),
        _ => native_scan(right, Nat.sub(source, left_source), Nat.add(offset, left_native)))

def to_native(tree: Tree, source: Nat) -> Nat:
  native_scan(tree, source, 0n)

# Materialize the complete scalar map for reference checks and diagnostics.
# Native editing uses tree paths and does not call this function.
def append_points(tree: Tree, +offset: Nat, tail: List<&2, Nat>) -> List<&2, Nat>:
  match tree:
    case Empty{}:
      tail
    case Leaf{Chunk{visible, points, source, native, last, id, start, end, runs}}:
      List.reverse.go(&2, Nat, List.reverse(&2, Nat, Scene.offset_points(Scene.without_end(points), offset)), tail)
    case Branch{+left, right, source, native, last, count, height}:
      +left_source = source_length(left)
      append_points(left, offset, append_points(right, Nat.add(offset, left_source), tail))

def points(+tree: Tree) -> List<&2, Nat>:
  +finish = source_length(tree)
  append_points(tree, 0n, [finish])

def runs(tree: Tree, tail: List<&2, Scene.Run>) -> List<&2, Scene.Run>:
  match tree:
    case Empty{}:
      tail
    case Leaf{Chunk{visible, points, source, native, last, id, start, end, local}}:
      List.reverse.go(&2, Scene.Run, List.reverse(&2, Scene.Run, local), tail)
    case Branch{left, right, source, native, last, count, height}:
      runs(left, runs(right, tail))

def full_scene(scene: Scene.Scene, tree: Tree) -> Scene.Scene:
  match scene:
    case Scene.Scene{runs, old_points}:
      Scene.Scene{runs, points(tree)}
