import Base
import ../src/SceneIndex.bend as T
import ../src/BlockScene.bend as Scene
import ./DirectCheck.bend as Check

def item(+source: String, id: Nat) -> T.Chunk:
  T.chunk(Scene.build(source, 10000n, 10000n), String.length(source), id, 0n, 0n)

def valid(+tree: T.Tree) -> Bool:
  match tree:
    case T.Empty{}:
      True{}
    case T.Leaf{chunk}:
      True{}
    case T.Branch{+left, +right, source, native, last, count, height}:
      +expected = T.node(left, right)
      valid(left) && valid(right) &&
        Nat.is_gt(T.count(left), 0n) && Nat.is_gt(T.count(right), 0n) &&
        Nat.is_le(T.height(left), 1n+T.height(right)) &&
        Nat.is_le(T.height(right), 1n+T.height(left)) &&
        Nat.is_eq(source, T.source_length(expected)) &&
        Nat.is_eq(native, T.native_length(expected)) &&
        Nat.is_eq(last, T.last_point(expected)) &&
        Nat.is_eq(count, T.count(expected)) && Nat.is_eq(height, T.height(expected))

def ids(tree: T.Tree, tail: List<&2, Nat>) -> List<&2, Nat>:
  match tree:
    case T.Empty{}:
      tail
    case T.Leaf{T.Chunk{visible, points, source, native, last, id, start, end, runs}}:
      id <> tail
    case T.Branch{left, right, source, native, last, count, height}:
      ids(left, ids(right, tail))

def equal(a: List<&2, Nat>, b: List<&2, Nat>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case x <> rest y <> later:
      Nat.is_eq(x, y) && equal(rest, later)
    case _ _:
      False{}

def positions(fuel: Nat, +actual: T.Tree, +expected: T.Tree, +at: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        Check.check(Nat.is_eq(T.to_source(actual, at), T.to_source(expected, at)))
        Check.check(Nat.is_eq(T.to_native(actual, at), T.to_native(expected, at)))
        positions(rest, actual, expected, 1n+at)

def compare(+actual: T.Tree, +expected: T.Tree) -> IO(Unit):
  do IO<Unit>:
    Check.check(valid(actual))
    Check.check(Nat.is_eq(T.count(actual), T.count(expected)))
    Check.check(Nat.is_eq(T.source_length(actual), T.source_length(expected)))
    Check.check(Nat.is_eq(T.native_length(actual), T.native_length(expected)))
    Check.check(equal(ids(actual, Nil{}), ids(expected, Nil{})))
    Check.check(equal(T.points(actual), T.points(expected)))
    positions(3n+Nat.max(T.source_length(expected), T.native_length(expected)),
      actual, expected, 0n)

def removals(fuel: Nat, +chunks: List<&2, T.Chunk>, +tree: T.Tree,
  +first: Nat, +removed: Nat, +inserted: List<&2, T.Chunk>) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      +expected = List.append(&2, T.Chunk, List.take(&2, T.Chunk, chunks, first),
        List.append(&2, T.Chunk, inserted,
          List.drop(&2, T.Chunk, List.drop(&2, T.Chunk, chunks, first), removed)))
      do IO<Unit>:
        compare(T.splice(tree, first, removed, inserted), T.build(expected))
        removals(rest, chunks, tree, first, 1n+removed, inserted)

def starts(fuel: Nat, +chunks: List<&2, T.Chunk>, +tree: T.Tree,
  +first: Nat, +inserted: List<&2, T.Chunk>) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        removals(3n+List.length(&2, T.Chunk, chunks), chunks, tree, first, 0n, inserted)
        starts(rest, chunks, tree, 1n+first, inserted)

def appended(fuel: Nat, +tree: T.Tree, +chunks: List<&2, T.Chunk>, +next: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        removals(8n, chunks, tree, Nat.div(T.count(tree), 2n), 0n,
          [item("```\n```\n", next), item("😀", 1n+next)])
        removals(8n, chunks, tree, 0n, 0n, [item("😀", next)])
    case 1n+rest:
      +chunk = item("**😀**\r\n", next)
      +updated = T.splice(tree, T.count(tree), 0n, [chunk])
      +values = List.append(&2, T.Chunk, chunks, [chunk])
      do IO<Unit>:
        compare(updated, T.build(values))
        compare(T.splice(updated, 0n, 1n, Nil{}),
          T.build(List.drop(&2, T.Chunk, values, 1n)))
        appended(rest, updated, values, 1n+next)

def main() -> IO(Unit):
  +chunks : List<&2, T.Chunk> = [item("# H\n", 0n), item("```\n```\n", 1n),
    item("**😀**\n", 2n), item("\n", 3n), item("中文\r\n", 4n),
    item("~~~\n~~~\n", 5n), item("*é*\n", 6n), item("", 7n), item("tail", 8n)]
  +tree = T.build(chunks)
  do IO<Unit>:
    starts(12n, chunks, tree, 0n, Nil{})
    starts(12n, chunks, tree, 0n, [item("😀", 9n)])
    starts(12n, chunks, tree, 0n,
      [item("```\n```\n", 9n), item("# 😀\n", 10n), item("", 11n)])
    compare(T.splice(T.Empty{}, 8n, 10n, chunks), tree)
    appended(129n, T.Empty{}, Nil{}, 0n)
    IO.print("Scene range update batch passed")
