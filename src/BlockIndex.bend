import Base

# Persistent AVL sequence. Cached scalar lengths locate an edit without scanning
# source text. Cached block counts split the sequence at block boundaries.
type Tree<-A: Data> is Data:
  Empty{}
  Leaf{value: A, length: Nat}
  Branch{left: Tree<A>, right: Tree<A>, length: Nat, count: Nat, height: Nat}

type Split<-A: Data> is Data:
  Split{left: Tree<A>, right: Tree<A>}

type Pop<-A: Data> is Data:
  Pop{item: Maybe<&2, A>, rest: Tree<A>}

type Built<-A: Data> is Data:
  Built{tree: Tree<A>, rest: List<&2, A>}

def length(-A: Data, tree: Tree<A>) -> Nat:
  match tree:
    case Empty{}:
      0n
    case Leaf{value, length}:
      length
    case Branch{left, right, length, count, height}:
      length

def count(-A: Data, tree: Tree<A>) -> Nat:
  match tree:
    case Empty{}:
      0n
    case Leaf{value, length}:
      1n
    case Branch{left, right, length, count, height}:
      count

def height(-A: Data, tree: Tree<A>) -> Nat:
  match tree:
    case Empty{}:
      0n
    case Leaf{value, length}:
      1n
    case Branch{left, right, length, count, height}:
      height

def node(-A: Data, +left: Tree<A>, +right: Tree<A>) -> Tree<A>:
  match left right:
    case Empty{} _:
      right
    case _ Empty{}:
      left
    case _ _:
      Branch{left, right, Nat.add(length(A, left), length(A, right)),
        Nat.add(count(A, left), count(A, right)),
        1n+Nat.max(height(A, left), height(A, right))}

def rotate_left_inner(-A: Data, left: Tree<A>, +middle: Tree<A>, right: Tree<A>) -> Tree<A>:
  match middle:
    case Branch{a, b, length, count, height}:
      node(A, node(A, left, a), node(A, b, right))
    case _:
      node(A, node(A, left, middle), right)

def rotate_left_choice(-A: Data, single: Bool, left: Tree<A>, middle: Tree<A>, right: Tree<A>) -> Tree<A>:
  match single:
    case True{}:
      node(A, node(A, left, middle), right)
    case False{}:
      rotate_left_inner(A, left, middle, right)

def rotate_left(-A: Data, left: Tree<A>, +right: Tree<A>) -> Tree<A>:
  match right:
    case Branch{+a, +b, size, items, h}:
      rotate_left_choice(A, Nat.is_le(height(A, a), height(A, b)), left, a, b)
    case _:
      node(A, left, right)

def rotate_right_inner(-A: Data, left: Tree<A>, +middle: Tree<A>, right: Tree<A>) -> Tree<A>:
  match middle:
    case Branch{a, b, length, count, height}:
      node(A, node(A, left, a), node(A, b, right))
    case _:
      node(A, left, node(A, middle, right))

def rotate_right_choice(-A: Data, single: Bool, left: Tree<A>, middle: Tree<A>, right: Tree<A>) -> Tree<A>:
  match single:
    case True{}:
      node(A, left, node(A, middle, right))
    case False{}:
      rotate_right_inner(A, left, middle, right)

def rotate_right(-A: Data, +left: Tree<A>, right: Tree<A>) -> Tree<A>:
  match left:
    case Branch{+a, +b, size, items, h}:
      rotate_right_choice(A, Nat.is_ge(height(A, a), height(A, b)), a, b, right)
    case _:
      node(A, left, right)

def balance_choice(-A: Data, left_tall: Bool, right_tall: Bool, left: Tree<A>, right: Tree<A>) -> Tree<A>:
  match left_tall right_tall:
    case True{} _:
      rotate_right(A, left, right)
    case _ True{}:
      rotate_left(A, left, right)
    case _ _:
      node(A, left, right)

def balance(-A: Data, +left: Tree<A>, +right: Tree<A>) -> Tree<A>:
  balance_choice(A, Nat.is_gt(height(A, left), 1n+height(A, right)),
    Nat.is_gt(height(A, right), 1n+height(A, left)), left, right)

def join_choice(-A: Data, left_tall: Bool, right_tall: Bool,
  normal: Unit -> Tree<A>, left: Unit -> Tree<A>, right: Unit -> Tree<A>) -> Tree<A>:
  match left_tall right_tall:
    case True{} _:
      left(Unit{})
    case _ True{}:
      right(Unit{})
    case _ _:
      normal(Unit{})

def concat(-A: Data, +left: Tree<A>, +right: Tree<A>) -> Tree<A>:
  match left right:
    case Empty{} _:
      right
    case _ Empty{}:
      left
    case Leaf{value, width} Leaf{other, size}:
      node(A, left, right)
    case Branch{+a, +b, size, count, +h} Leaf{value, width}:
      join_choice(A, Nat.is_gt(h, 2n), False{}, _ => node(A, left, right),
        _ => balance(A, a, concat(A, b, right)), _ => node(A, left, right))
    case Leaf{value, width} Branch{+a, +b, size, count, +h}:
      join_choice(A, False{}, Nat.is_gt(h, 2n), _ => node(A, left, right),
        _ => node(A, left, right), _ => balance(A, concat(A, left, a), b))
    case Branch{+a, +b, size, count, +h} Branch{+c, +d, other, items, +k}:
      join_choice(A, Nat.is_gt(h, 1n+k), Nat.is_gt(k, 1n+h), _ => node(A, left, right),
        _ => balance(A, a, concat(A, b, right)), _ => balance(A, concat(A, left, c), d))

def flatten(-A: Data, tree: Tree<A>, tail: List<&2, A>) -> List<&2, A>:
  match tree:
    case Empty{}:
      tail
    case Leaf{value, width}:
      value <> tail
    case Branch{left, right, size, count, height}:
      flatten(A, left, flatten(A, right, tail))

def built_node(-A: Data, left: Tree<A>, right: Built<A>) -> Built<A>:
  match right:
    case Built{tree, rest}:
      Built{node(A, left, tree), rest}

def built_right(-A: Data, left: Built<A>, next: List<&2, A> -> Built<A>) -> Built<A>:
  match left:
    case Built{tree, rest}:
      built_node(A, tree, next(rest))

# Consume each list item once. Both halves differ by at most one item, so their
# heights permit a direct node rather than the general AVL join operation.
# The right half depends on the remainder from the left half.
def build_size(~A: Data, ~width: A -> Nat, +fuel: Nat, size: Nat,
  values: List<&2, A>) -> Built<A>:
  match fuel size values:
    case _ 0n _:
      Built{Empty{}, values}
    case _ _ Nil{}:
      Built{Empty{}, Nil{}}
    case _ 1n +value <> rest:
      Built{Leaf{value, width(value)}, rest}
    case 1n+rest 1n+1n+more _:
      +items = Nat.add(2n, more)
      +left_size = Nat.div(items, 2n)
      +right_size = Nat.sub(items, left_size)
      built_right(A, build_size(~A, ~width, rest, left_size, values),
        later => build_size(~A, ~width, rest, right_size, later))
    case 0n _ _:
      Built{Empty{}, values}

def built_tree(-A: Data, result: Built<A>) -> Tree<A>:
  match result:
    case Built{tree, rest}:
      tree

def list_count(-A: Data, values: List<&2, A>, count: Nat) -> Nat:
  match values:
    case Nil{}:
      count
    case _ <> rest:
      list_count(A, rest, 1n+count)

def from_list(~A: Data, ~width: A -> Nat, +values: List<&2, A>) -> Tree<A>:
  +size = list_count(A, values, 0n)
  built_tree(A, build_size(~A, ~width, size, size, values))

def split_left(-A: Data, result: Split<A>, other: Tree<A>) -> Split<A>:
  match result:
    case Split{left, right}:
      Split{left, concat(A, right, other)}

def split_right(-A: Data, other: Tree<A>, result: Split<A>) -> Split<A>:
  match result:
    case Split{left, right}:
      Split{concat(A, other, left), right}

def split_choice(-A: Data, zero: Bool, all: Bool, tree: Tree<A>, rest: Unit -> Split<A>) -> Split<A>:
  match zero all:
    case True{} _:
      Split{Empty{}, tree}
    case _ True{}:
      Split{tree, Empty{}}
    case _ _:
      rest(Unit{})

def choose_split(-A: Data, left: Bool, a: Unit -> Split<A>, b: Unit -> Split<A>) -> Split<A>:
  match left:
    case True{}:
      a(Unit{})
    case False{}:
      b(Unit{})

def split(-A: Data, +tree: Tree<A>, +index: Nat) -> Split<A>:
  match tree:
    case Empty{}:
      Split{Empty{}, Empty{}}
    case Leaf{value, size}:
      split_choice(A, Nat.is_eq(index, 0n), True{}, tree, _ => Split{Empty{}, Empty{}})
    case Branch{+left, +right, size, +items, height}:
      +left_count = count(A, left)
      split_choice(A, Nat.is_eq(index, 0n), Nat.is_ge(index, items), tree,
        _ => choose_split(A, Nat.is_lt(index, left_count),
          _ => split_left(A, split(A, left, index), right),
          _ => split_right(A, left, split(A, right, Nat.sub(index, left_count)))))

def rank_choice(hit: Bool, index: Nat) -> Nat:
  match hit:
    case True{}:
      index
    case False{}:
      1n+index

def rank_branch(hit: Bool, left: Unit -> Nat, right: Unit -> Nat) -> Nat:
  match hit:
    case True{}:
      left(Unit{})
    case False{}:
      right(Unit{})

def rank(-A: Data, tree: Tree<A>, +position: Nat, +index: Nat) -> Nat:
  match tree:
    case Empty{}:
      index
    case Leaf{value, width}:
      rank_choice(Nat.is_lt(position, width), index)
    case Branch{+left, right, size, items, h}:
      +width = length(A, left)
      # Capture the scalar count, not a tree used only by a borrowed accessor.
      # Bend 2.0.34 retains that tree in the right-branch closure otherwise.
      +left_count = count(A, left)
      rank_branch(Nat.is_lt(position, width), _ => rank(A, left, position, index),
        _ => rank(A, right, Nat.sub(position, width), Nat.add(index, left_count)))

def first(-A: Data, tree: Tree<A>) -> Maybe<&2, A>:
  match tree:
    case Empty{}:
      None{}
    case Leaf{value, width}:
      Some{value}
    case Branch{left, right, size, count, height}:
      first(A, left)

def popped(-A: Data, result: Split<A>) -> Pop<A>:
  match result:
    case Split{left, right}:
      Pop{first(A, left), right}

def pop(-A: Data, tree: Tree<A>) -> Pop<A>:
  popped(A, split(A, tree, 1n))

def valid(~A: Data, ~width: A -> Nat, tree: Tree<A>) -> Bool:
  match tree:
    case Empty{}:
      True{}
    case Leaf{+value, size}:
      Nat.is_eq(size, width(value))
    case Branch{+left, +right, size, items, h}:
      left_valid right_valid = valid(~A, ~width, left) valid(~A, ~width, right)
      left_valid && right_valid &&
        Nat.is_eq(size, Nat.add(length(A, left), length(A, right))) &&
        Nat.is_eq(items, Nat.add(count(A, left), count(A, right))) &&
        Nat.is_eq(h, 1n+Nat.max(height(A, left), height(A, right))) &&
        Nat.is_gt(height(A, left), 0n) && Nat.is_gt(height(A, right), 0n) &&
        Nat.is_le(height(A, left), 1n+height(A, right)) &&
        Nat.is_le(height(A, right), 1n+height(A, left))
