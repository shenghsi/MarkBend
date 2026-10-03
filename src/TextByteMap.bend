import Base
import ./BlockIndex.bend as Index
import ./Utf8.bend as Utf8

type Span is Data:
  Span{text: String, scalars: Nat, bytes: Nat}

# Both trees have the same spans and shape. One caches scalar lengths and the
# other caches byte lengths. A span holds at most 128 valid Unicode scalars.
type Mapping is Data:
  Mapping{scalars: Index.Tree<Span>, bytes: Index.Tree<Span>}

def scalar_width(span: Span) -> Nat:
  match span:
    case Span{text, scalars, bytes}:
      scalars

def byte_width(span: Span) -> Nat:
  match span:
    case Span{text, scalars, bytes}:
      bytes

def width_choice(one: Bool, two: Bool, three: Bool) -> Nat:
  match one two three:
    case True{} _ _:
      1n
    case _ True{} _:
      2n
    case _ _ True{}:
      3n
    case _ _ _:
      4n

def char_width(+code: U32) -> Nat:
  width_choice(U32.is_le(code, 127), U32.is_le(code, 2047), U32.is_le(code, 65535))

def prefix(text: String, position: Nat, bytes: Nat) -> Nat:
  match text position:
    case _ 0n:
      bytes
    case SNil{} _:
      bytes
    case SCon{Chr{code}, rest} 1n+left:
      prefix(rest, left, Nat.add(bytes, char_width(code)))

def span(+text: String) -> Span:
  Span{text, String.length(text), prefix(text, 128n, 0n)}

def finish(current: String, acc: List<&2, Span>) -> List<&2, Span>:
  match current:
    case SNil{}:
      List.reverse(&2, Span, acc)
    case current:
      List.reverse(&2, Span, span(String.reverse(current)) <> acc)

def spans(text: String, remaining: Nat, current: String,
  acc: List<&2, Span>) -> List<&2, Span>:
  match text remaining:
    case SNil{} _:
      finish(current, acc)
    case SCon{char, rest} 0n:
      spans(rest, 127n, SCon{char, SNil{}}, span(String.reverse(current)) <> acc)
    case SCon{char, rest} 1n+left:
      spans(rest, left, SCon{char, current}, acc)

def valid_text(text: String, ok: Bool) -> Bool:
  match text:
    case SNil{}:
      ok
    case SCon{Chr{code}, rest}:
      valid_text(rest, ok && Utf8.scalar(code))

def span_count(spans: List<&2, Span>, acc: Nat) -> Nat:
  match spans:
    case Nil{}:
      acc
    case head <> rest:
      span_count(rest, 1n+acc)

def build(+spans: List<&2, Span>) -> Mapping:
  +size = span_count(spans, 0n)
  scalars bytes = Index.built_tree(Span, Index.build_size(~Span, ~scalar_width, size, size, spans))
    Index.built_tree(Span, Index.build_size(~Span, ~byte_width, size, size, spans))
  Mapping{scalars, bytes}

def from_gate(ok: Bool, text: String) -> Maybe<&2, Mapping>:
  match ok:
    case True{}:
      Some{build(spans(text, 128n, "", Nil{}))}
    case False{}:
      None{}

def from_text(+text: String) -> Maybe<&2, Mapping>:
  from_gate(valid_text(text, True{}), text)

def choose(left: Bool, first: Unit -> Maybe<&2, Nat>, second: Unit -> Maybe<&2, Nat>) ->
  Maybe<&2, Nat>:
  match left:
    case True{}:
      first(Unit{})
    case False{}:
      second(Unit{})

def scan(scalars: Index.Tree<Span>, bytes: Index.Tree<Span>, +position: Nat,
  +offset: Nat) -> Maybe<&2, Nat>:
  match scalars bytes:
    case Index.Empty{} Index.Empty{}:
      Some{offset}
    case Index.Leaf{Span{text, count, width}, length} Index.Leaf{span, size}:
      Some{Nat.add(offset, prefix(text, position, 0n))}
    case Index.Branch{+a, b, length, count, height}
      Index.Branch{+c, d, size, items, h}:
      +left_scalars = Index.length(Span, a)
      +left_bytes = Index.length(Span, c)
      choose(Nat.is_lt(position, left_scalars),
        _ => scan(a, c, position, offset),
        _ => scan(b, d, Nat.sub(position, left_scalars), Nat.add(offset, left_bytes)))
    case _ _:
      None{}

# Clamp beyond the final scalar. Return None if a manually constructed map has
# mismatched tree shapes. No source prefix is materialized during this lookup.
def to_byte(map: Mapping, position: Nat) -> Maybe<&2, Nat>:
  match map:
    case Mapping{scalars, bytes}:
      scan(scalars, bytes, position, 0n)

def trimmed(prefix: Index.Tree<Span>, suffix: Index.Split<Span>,
  added: Index.Tree<Span>) -> Index.Tree<Span>:
  match suffix:
    case Index.Split{removed, rest}:
      Index.concat(Span, Index.concat(Span, prefix, added), rest)

def split_replace(value: Index.Split<Span>, removed: Nat,
  added: Index.Tree<Span>) -> Index.Tree<Span>:
  match value:
    case Index.Split{prefix, suffix}:
      trimmed(prefix, Index.split(Span, suffix, removed), added)

def replace_tree(tree: Index.Tree<Span>, first: Nat, removed: Nat,
  added: Index.Tree<Span>) -> Index.Tree<Span>:
  split_replace(Index.split(Span, tree, first), removed, added)

# The caller replaces whole spans after handling boundary text. The unchanged
# prefix and suffix retain their spans. This is not a scalar-range edit API.
def replace_spans(map: Mapping, +first: Nat, +removed: Nat, added: Mapping) -> Mapping:
  match map added:
    case Mapping{scalars, bytes} Mapping{new_scalars, new_bytes}:
      next_scalars next_bytes = replace_tree(scalars, first, removed, new_scalars)
        replace_tree(bytes, first, removed, new_bytes)
      Mapping{next_scalars, next_bytes}

def span_valid(value: Span) -> Bool:
  match value:
    case Span{+text, +scalars, bytes}:
      Nat.is_gt(scalars, 0n) && Nat.is_le(scalars, 128n) &&
        Nat.is_eq(scalars, String.length(text)) && valid_text(text, True{}) &&
        Nat.is_eq(bytes, prefix(text, 128n, 0n))

def same_span(+a: Span, b: Span) -> Bool:
  match a b:
    case Span{text, scalars, bytes} Span{other, count, length}:
      span_valid(a) && String.eq(text, other) &&
        Nat.is_eq(scalars, count) && Nat.is_eq(bytes, length)

def mirrored(left: Index.Tree<Span>, right: Index.Tree<Span>) -> Bool:
  match left right:
    case Index.Empty{} Index.Empty{}:
      True{}
    case Index.Leaf{a, size} Index.Leaf{b, width}:
      same_span(a, b)
    case Index.Branch{a, b, size, count, height} Index.Branch{c, d, width, items, h}:
      first second = mirrored(a, c) mirrored(b, d)
      first && second
    case _ _:
      False{}

def valid(map: Mapping) -> Bool:
  match map:
    case Mapping{+scalars, +bytes}:
      Index.valid(~Span, ~scalar_width, scalars) && Index.valid(~Span, ~byte_width, bytes) &&
        mirrored(scalars, bytes)

type Boundary is Data:
  Boundary{rank: Nat, offset: Nat, text: String, present: Bool}

def boundary_span(value: Maybe<&2, Span>, rank: Nat, offset: Nat) -> Boundary:
  match value:
    case Some{Span{text, scalars, bytes}}:
      Boundary{rank, offset, text, True{}}
    case None{}:
      Boundary{rank, 0n, "", False{}}

def boundary_split(value: Index.Split<Span>, rank: Nat, position: Nat) -> Boundary:
  match value:
    case Index.Split{prefix, suffix}:
      boundary_span(Index.first(Span, suffix), rank,
        Nat.sub(position, Index.length(Span, prefix)))

def boundary_rank(+tree: Index.Tree<Span>, +rank: Nat, position: Nat) -> Boundary:
  boundary_split(Index.split(Span, tree, rank), rank, position)

def boundary(+map: Mapping, position: Nat) -> Boundary:
  match map:
    case Mapping{+scalars, bytes}:
      +clamped = Nat.min(position, Index.length(Span, scalars))
      boundary_rank(scalars, Index.rank(Span, scalars, clamped, 0n), clamped)

def restore_text(reversed: String, suffix: String) -> String:
  match reversed:
    case SNil{}:
      suffix
    case SCon{char, rest}:
      restore_text(rest, SCon{char, suffix})

def append_text(text: String, suffix: String) -> String:
  restore_text(String.reverse(text), suffix)

def after_span(present: Bool, rank: Nat) -> Nat:
  match present:
    case True{}:
      1n+rank
    case False{}:
      rank

def added_range(value: Maybe<&2, Mapping>, map: Mapping, first: Nat,
  removed: Nat) -> Maybe<&2, Mapping>:
  match value:
    case Some{added}:
      Some{replace_spans(map, first, removed, added)}
    case None{}:
      None{}

def replace_boundaries(low: Boundary, high: Boundary, map: Mapping,
  insert: String) -> Maybe<&2, Mapping>:
  match low high:
    case Boundary{+first, offset, text, present}
      Boundary{last, end, suffix, exists}:
      added_range(from_text(append_text(String.take(text, offset),
        append_text(insert, String.drop(suffix, end)))), map, first,
        Nat.sub(after_span(exists, last), first))

# Replace a clamped, possibly reversed scalar range. Rebuild only its boundary
# spans and inserted text. No unchanged source prefix or suffix is materialized.
def replace(+map: Mapping, +start: Nat, +end: Nat,
  insert: String) -> Maybe<&2, Mapping>:
  replace_boundaries(boundary(map, Nat.min(start, end)),
    boundary(map, Nat.max(start, end)), map, insert)
