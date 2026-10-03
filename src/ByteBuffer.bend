import Base
import ./BlockIndex.bend as Index

type Chunk is Data:
  Chunk{bytes: List<&2, U32>}

type Buffer is Data:
  Buffer{tree: Index.Tree<Chunk>}

def width(chunk: Chunk) -> Nat:
  match chunk:
    case Chunk{bytes}:
      List.length(&2, U32, bytes)

def finish_chunks(current: List<&2, U32>, acc: List<&2, Chunk>) -> List<&2, Chunk>:
  match current:
    case Nil{}:
      List.reverse(&2, Chunk, acc)
    case current:
      List.reverse(&2, Chunk, Chunk{List.reverse(&2, U32, current)} <> acc)

def chunks(bytes: List<&2, U32>, current: List<&2, U32>, remaining: Nat,
  acc: List<&2, Chunk>) -> List<&2, Chunk>:
  match bytes remaining:
    case Nil{} _:
      finish_chunks(current, acc)
    case byte <> rest 0n:
      chunks(rest, [byte], 511n, Chunk{List.reverse(&2, U32, current)} <> acc)
    case byte <> rest 1n+left:
      chunks(rest, byte <> current, left, acc)

def valid_bytes(bytes: List<&2, U32>, ok: Bool) -> Bool:
  match bytes:
    case Nil{}:
      ok
    case byte <> rest:
      valid_bytes(rest, ok && U32.is_le(byte, 255))

def from_gate(ok: Bool, bytes: List<&2, U32>) -> Maybe<&2, Buffer>:
  match ok:
    case True{}:
      Some{Buffer{Index.from_list(~Chunk, ~width, chunks(bytes, Nil{}, 512n, Nil{}))}}
    case False{}:
      None{}

# Store arbitrary bytes, including invalid UTF-8. Text validation is separate.
def from_bytes(+bytes: List<&2, U32>) -> Maybe<&2, Buffer>:
  from_gate(valid_bytes(bytes, True{}), bytes)

def leaf(+bytes: List<&2, U32>) -> Index.Tree<Chunk>:
  match bytes:
    case Nil{}:
      Index.Empty{}
    case bytes:
      Index.Leaf{Chunk{bytes}, List.length(&2, U32, bytes)}

def split_bytes(+tree: Index.Tree<Chunk>, +position: Nat) -> Index.Split<Chunk>:
  match tree:
    case Index.Empty{}:
      Index.Split{Index.Empty{}, Index.Empty{}}
    case Index.Leaf{Chunk{+bytes}, size}:
      Index.Split{leaf(List.take(&2, U32, bytes, position)),
        leaf(List.drop(&2, U32, bytes, position))}
    case Index.Branch{+left, +right, size, count, height}:
      Index.choose_split(Chunk, Nat.is_le(position, Index.length(Chunk, left)),
        _ => Index.split_left(Chunk, split_bytes(left, position), right),
        _ => Index.split_right(Chunk, left,
          split_bytes(right, Nat.sub(position, Index.length(Chunk, left)))))

def trimmed(prefix: Index.Tree<Chunk>, result: Index.Split<Chunk>,
  insert: Index.Tree<Chunk>) -> Buffer:
  match result:
    case Index.Split{removed, suffix}:
      Buffer{Index.concat(Chunk, Index.concat(Chunk, prefix, insert), suffix)}

def replaced(result: Index.Split<Chunk>, removed: Nat, insert: Index.Tree<Chunk>) -> Buffer:
  match result:
    case Index.Split{prefix, rest}:
      trimmed(prefix, split_bytes(rest, removed), insert)

# Positions count bytes, not scalars or UTF-16 units. Clamp at buffer ends and
# accept reversed ranges. Only callers with valid text positions may use this
# operation for an editable UTF-8 document. The raw buffer permits any bytes.
def replace(buffer: Buffer, +start: Nat, +end: Nat, insert: Buffer) -> Buffer:
  match buffer insert:
    case Buffer{tree} Buffer{added}:
      replaced(split_bytes(tree, Nat.min(start, end)),
        Nat.sub(Nat.max(start, end), Nat.min(start, end)), added)

def prepend(bytes: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match bytes:
    case Nil{}:
      acc
    case byte <> rest:
      prepend(rest, byte <> acc)

def materialize_chunks(chunks: List<&2, Chunk>, acc: List<&2, U32>) -> List<&2, U32>:
  match chunks:
    case Nil{}:
      List.reverse(&2, U32, acc)
    case Chunk{bytes} <> rest:
      materialize_chunks(rest, prepend(bytes, acc))

# Materialize only when an effect or record codec needs a flat byte list.
def materialize(buffer: Buffer) -> List<&2, U32>:
  match buffer:
    case Buffer{tree}:
      materialize_chunks(Index.flatten(Chunk, tree, Nil{}), Nil{})

def length(buffer: Buffer) -> Nat:
  match buffer:
    case Buffer{tree}:
      Index.length(Chunk, tree)

# Compare bytes across different chunk boundaries without a flat byte copy.
# Chunk traversal still visits the complete equal prefix.
def equal_chunks(chunks_left: List<&2, Chunk>, chunks_right: List<&2, Chunk>,
  a: List<&2, U32>, b: List<&2, U32>, ok: Bool) -> Bool:
  match chunks_left chunks_right a b ok:
    case _ _ _ _ False{}:
      False{}
    case Nil{} Nil{} Nil{} Nil{} True{}:
      True{}
    case Chunk{bytes} <> rest right Nil{} b True{}:
      equal_chunks(rest, right, bytes, b, ok)
    case left Chunk{bytes} <> rest a Nil{} True{}:
      equal_chunks(left, rest, a, bytes, ok)
    case left right x <> xs y <> ys True{}:
      equal_chunks(left, right, xs, ys, ok && U32.is_eq(x, y))
    case _ _ _ _ _:
      False{}

def equal_length(same: Bool, a: Index.Tree<Chunk>, b: Index.Tree<Chunk>) -> Bool:
  match same:
    case False{}:
      False{}
    case True{}:
      equal_chunks(Index.flatten(Chunk, a, Nil{}),
        Index.flatten(Chunk, b, Nil{}), Nil{}, Nil{}, True{})

def equal(+left: Buffer, +right: Buffer) -> Bool:
  match left right:
    case Buffer{+a} Buffer{+b}:
      equal_length(Nat.is_eq(Index.length(Chunk, a), Index.length(Chunk, b)), a, b)

def chunk_valid(chunk: Chunk) -> Bool:
  match chunk:
    case Chunk{+bytes}:
      +size = List.length(&2, U32, bytes)
      Nat.is_gt(size, 0n) && Nat.is_le(size, 512n) && valid_bytes(bytes, True{})

def bounded(chunks: List<&2, Chunk>, ok: Bool) -> Bool:
  match chunks:
    case Nil{}:
      ok
    case chunk <> rest:
      bounded(rest, ok && chunk_valid(chunk))

def valid(buffer: Buffer) -> Bool:
  match buffer:
    case Buffer{+tree}:
      Index.valid(~Chunk, ~width, tree) && bounded(Index.flatten(Chunk, tree, Nil{}), True{})
