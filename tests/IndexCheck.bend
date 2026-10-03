import Base
import ../src/BlockIndex.bend as T

def check(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "Block index check failed")

def width(value: Nat) -> Nat:
  1n+value

def equal(a: List<&2, Nat>, b: List<&2, Nat>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case x <> rest y <> later:
      Nat.is_eq(x, y) && equal(rest, later)
    case _ _:
      False{}

def split_ok(result: T.Split<Nat>, +values: List<&2, Nat>, +index: Nat) -> Bool:
  match result:
    case T.Split{+left, +right}:
      T.valid(~Nat, ~width, left) && T.valid(~Nat, ~width, right) &&
        equal(T.flatten(Nat, left, Nil{}), List.take(&2, Nat, values, index)) &&
        equal(T.flatten(Nat, right, Nil{}), List.drop(&2, Nat, values, index)) &&
        T.valid(~Nat, ~width, T.concat(Nat, left, right)) &&
        equal(T.flatten(Nat, T.concat(Nat, left, right), Nil{}), values)

def splits(fuel: Nat, +tree: T.Tree<Nat>, +values: List<&2, Nat>, +index: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        check(split_ok(T.split(Nat, tree, index), values, index))
        splits(rest, tree, values, 1n+index)

def rank_hit(hit: Bool, index: Nat, rest: Unit -> Nat) -> Nat:
  match hit:
    case True{}:
      index
    case False{}:
      rest(Unit{})

def naive_rank(values: List<&2, Nat>, +position: Nat, +index: Nat) -> Nat:
  match values:
    case Nil{}:
      index
    case +value <> rest:
      rank_hit(Nat.is_lt(position, width(value)), index,
        _ => naive_rank(rest, Nat.sub(position, width(value)), 1n+index))

def ranks(fuel: Nat, +tree: T.Tree<Nat>, +values: List<&2, Nat>, +position: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        check(Nat.is_eq(T.rank(Nat, tree, position, 0n), naive_rank(values, position, 0n)))
        ranks(rest, tree, values, 1n+position)

def sizes(fuel: Nat, +size: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      +values = List.range(size)
      +tree = T.from_list(~Nat, ~width, values)
      do IO<Unit>:
        check(T.valid(~Nat, ~width, tree))
        check(equal(T.flatten(Nat, tree, Nil{}), values))
        splits(2n+size, tree, values, 0n)
        ranks(2n+T.length(Nat, tree), tree, values, 0n)
        sizes(rest, 1n+size)

def appended(fuel: Nat, +index: Nat, tree: T.Tree<Nat>) -> T.Tree<Nat>:
  match fuel:
    case 0n:
      tree
    case 1n+rest:
      appended(rest, 1n+index, T.concat(Nat, tree, T.Leaf{index, width(index)}))

def bulk(+size: Nat) -> IO(Unit):
  +values = List.range(size)
  +tree = T.from_list(~Nat, ~width, values)
  do IO<Unit>:
    check(T.valid(~Nat, ~width, tree))
    check(Nat.is_eq(T.count(Nat, tree), size))
    check(equal(T.flatten(Nat, tree, Nil{}), values))
    check(Nat.is_eq(T.rank(Nat, tree, T.length(Nat, tree), 0n), size))
    check(split_ok(T.split(Nat, tree, Nat.div(size, 2n)), values, Nat.div(size, 2n)))

def main() -> IO(Unit):
  +tree = appended(257n, 0n, T.Empty{})
  do IO<Unit>:
    check(T.valid(~Nat, ~width, tree))
    check(equal(T.flatten(Nat, tree, Nil{}), List.range(257n)))
    check(Bool.not(T.valid(~Nat, ~width, T.Leaf{3n, 1n})))
    splits(259n, tree, List.range(257n), 0n)
    sizes(65n, 0n)
    bulk(127n)
    bulk(128n)
    bulk(129n)
    bulk(1023n)
    bulk(1024n)
    bulk(1025n)
    IO.print("Block index batch passed")
