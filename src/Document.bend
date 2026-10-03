import Base
import ./Blocks.bend as B
import ./TextPosition.bend as Position
import ./BlockIndex.bend as T

type Block is Data:
  Block{id: Nat, kind: B.BlockKind, source: String}

type Document is Data:
  Document{blocks: T.Tree<Block>, next_id: Nat, reparsed: Nat}

# Replace the old block interval [first, first + removed) with added blocks.
# The prefix and settled suffix keep their identifiers, kinds, and exact text.
type Change is Data:
  Change{document: Document, first: Nat, removed: Nat, added: Nat}

def changed(change: Change) -> Document:
  match change:
    case Change{document, first, removed, added}:
      document

def interval(change: Change) -> Nat & (Nat & Nat):
  match change:
    case Change{document, first, removed, added}:
      (first, (removed, added))

type View is Data:
  View{blocks: List<&2, Block>, next_id: Nat, reparsed: Nat}

type Assigned is Data:
  Assigned{blocks: List<&2, Block>, next_id: Nat}

type Region is Data:
  Region{mode: B.Mode, fresh_reversed: List<&2, B.Piece>, old_reversed: List<&2, Block>,
    parsed: Nat, pending: String}

type Reparsed is Data:
  Reparsed{fresh: List<&2, B.Piece>, old: List<&2, Block>, suffix: T.Tree<Block>, count: Nat}

def prepend_text(text: String, reversed: String) -> String:
  match text:
    case SNil{}:
      reversed
    case SCon{char, rest}:
      prepend_text(rest, SCon{char, reversed})

def source_loop(blocks: List<&2, Block>, reversed: String) -> String:
  match blocks:
    case Nil{}:
      String.reverse(reversed)
    case Block{id, kind, text} <> rest:
      source_loop(rest, prepend_text(text, reversed))

def source_list(blocks: List<&2, Block>) -> String:
  source_loop(blocks, SNil{})

def source(blocks: T.Tree<Block>) -> String:
  source_list(T.flatten(Block, blocks, Nil{}))

def pieces_list(blocks: List<&2, Block>) -> List<&2, B.Piece>:
  match blocks:
    case Nil{}:
      Nil{}
    case Block{id, kind, text} <> rest:
      B.Piece{kind, text} <> pieces_list(rest)

def pieces(blocks: T.Tree<Block>) -> List<&2, B.Piece>:
  pieces_list(T.flatten(Block, blocks, Nil{}))

def view(document: Document) -> View:
  match document:
    case Document{blocks, next, reparsed}:
      View{T.flatten(Block, blocks, Nil{}), next, reparsed}

def count_scalars(text: String, count: Nat) -> Nat:
  match text:
    case SNil{}:
      count
    case SCon{char, rest}:
      count_scalars(rest, 1n+count)

def block_length(block: Block) -> Nat:
  match block:
    case Block{id, kind, source}:
      String.length(source)

def same_bool(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}:
      True{}
    case False{} False{}:
      True{}
    case _ _:
      False{}

def same_kind(a: B.BlockKind, b: B.BlockKind) -> Bool:
  match a b:
    case B.Paragraph{} B.Paragraph{}:
      True{}
    case B.Blank{} B.Blank{}:
      True{}
    case B.Heading{a} B.Heading{b}:
      Nat.is_eq(a, b)
    case B.ListItem{a} B.ListItem{b}:
      same_bool(a, b)
    case B.Quote{} B.Quote{}:
      True{}
    case B.Fence{a, x, c} B.Fence{b, y, d}:
      Char.is_eq(a, b) && Nat.is_eq(x, y) && same_bool(c, d)
    case _ _:
      False{}

def text_equal_gate(same: Bool, rest: Unit -> Bool) -> Bool:
  match same:
    case True{}:
      rest(Unit{})
    case False{}:
      False{}

def text_equal(a: String, b: String) -> Bool:
  match a b:
    case SNil{} SNil{}:
      True{}
    case SCon{x, rest_a} SCon{y, rest_b}:
      text_equal_gate(Char.is_eq(x, y), _ => text_equal(rest_a, rest_b))
    case _ _:
      False{}

def same(piece: B.Piece, block: Block) -> Bool:
  match piece block:
    case B.Piece{a, x} Block{id, b, y}:
      same_kind(a, b) && text_equal(x, y)

def assign_push(block: Block, assigned: Assigned) -> Assigned:
  match assigned:
    case Assigned{blocks, next}:
      Assigned{block <> blocks, next}

def assign_loop(pieces: List<&2, B.Piece>, +id: Nat, reversed: List<&2, Block>) -> Assigned:
  match pieces:
    case Nil{}:
      Assigned{List.reverse(&2, Block, reversed), id}
    case B.Piece{kind, text} <> rest:
      assign_loop(rest, 1n+id, Block{id, kind, text} <> reversed)

def assign(pieces: List<&2, B.Piece>, id: Nat) -> Assigned:
  assign_loop(pieces, id, Nil{})

def created(assigned: Assigned, reparsed: Nat) -> Document:
  match assigned:
    case Assigned{blocks, next}:
      Document{T.from_list(~Block, ~block_length, blocks), next, reparsed}

def parse(+text: String) -> Document:
  created(assign(B.parse(text), 0n), count_scalars(text, 0n))

def join_assigned(prefix: List<&2, Block>, assigned: Assigned, suffix: List<&2, Block>) -> Assigned:
  match assigned:
    case Assigned{blocks, next}:
      Assigned{List.append(&2, Block, prefix, List.append(&2, Block, blocks, suffix)), next}

def suffix_choice(
  same: Bool, rest: List<&2, Block> -> Assigned,
  new_reversed: List<&2, B.Piece>, id: Nat, prefix: List<&2, Block>,
  +block: Block, kept: List<&2, Block>
) -> Assigned:
  match same:
    case True{}:
      rest(block <> kept)
    case False{}:
      join_assigned(prefix, assign(List.reverse(&2, B.Piece, new_reversed), id), kept)

def reuse_suffix(
  fresh: List<&2, B.Piece>, old: List<&2, Block>, kept: List<&2, Block>,
  +id: Nat, +prefix: List<&2, Block>
) -> Assigned:
  match fresh old:
    case +piece <> +rest +block <> previous:
      suffix_choice(same(piece, block),
        saved => reuse_suffix(rest, previous, saved, id, prefix),
        piece <> rest, id, prefix, block, kept)
    case _ _:
      join_assigned(prefix, assign(List.reverse(&2, B.Piece, fresh), id), kept)

# Both reversals visit one list cell per block. A local edit normally leaves
# similar block counts, so these independent calls have similar work.
def reconcile(fresh: List<&2, B.Piece>, old: List<&2, Block>, id: Nat,
  prefix: List<&2, Block>) -> Assigned:
  reversed_fresh reversed_old = List.reverse(&2, B.Piece, fresh) List.reverse(&2, Block, old)
  reuse_suffix(reversed_fresh, reversed_old, Nil{}, id, List.reverse(&2, Block, prefix))

def prefix_choice(
  same: Bool, rest: List<&2, Block> -> Assigned,
  fresh: List<&2, B.Piece>, old: List<&2, Block>, +id: Nat,
  +block: Block, prefix: List<&2, Block>
) -> Assigned:
  match same:
    case True{}:
      rest(block <> prefix)
    case False{}:
      reconcile(fresh, old, id, prefix)

def reuse_prefix(
  fresh: List<&2, B.Piece>, old: List<&2, Block>, +id: Nat,
  prefix: List<&2, Block>
) -> Assigned:
  match fresh old:
    case +piece <> +rest +block <> +previous:
      prefix_choice(same(piece, block),
        saved => reuse_prefix(rest, previous, id, saved),
        piece <> rest, block <> previous, id, block, prefix)
    case _ _:
      reconcile(fresh, old, id, prefix)

def can_stop(mode: B.Mode, next: B.BlockKind) -> Bool:
  match mode next:
    case B.Idle{} _:
      True{}
    case B.ParagraphOpen{lines} B.Paragraph{}:
      False{}
    case B.ParagraphOpen{lines} _:
      True{}
    case B.FenceOpen{marker, width, lines} _:
      False{}

def finish_region(region: Region, suffix: T.Tree<Block>) -> Reparsed:
  match region:
    case Region{mode, fresh, old, count, pending}:
      Reparsed{List.append(&2, B.Piece, List.reverse(&2, B.Piece, fresh), B.finish(mode)),
        List.reverse(&2, Block, old), suffix, count}

def fed(step: B.Step, fresh: List<&2, B.Piece>, old: List<&2, Block>, count: Nat) -> Region:
  match step:
    case B.Step{mode, emitted}:
      Region{mode, List.reverse.go(&2, B.Piece, emitted, fresh), old, count, ""}

def feed(+text: String, mode: B.Mode, fresh: List<&2, B.Piece>, old: List<&2, Block>, count: Nat)
  -> Region:
  fed(B.stream(B.lines(text), mode, Nil{}), fresh, old, Nat.add(count, String.length(text)))

def prepare(complete_line: Bool, +text: String, mode: B.Mode,
  fresh: List<&2, B.Piece>, old: List<&2, Block>, count: Nat) -> Region:
  match complete_line:
    case True{}:
      feed(text, mode, fresh, old, count)
    case False{}:
      Region{mode, fresh, old, count, text}

def grow_choice(stop: Bool, region: Region, suffix: T.Tree<Block>, rest: Unit -> Reparsed) -> Reparsed:
  match stop:
    case True{}:
      finish_region(region, suffix)
    case False{}:
      rest(Unit{})

def grow_popped(popped: T.Pop<Block>, region: Region, suffix: T.Tree<Block>,
  next: T.Tree<Block> -> Region -> Reparsed) -> Reparsed:
  match popped region:
    case T.Pop{None{}, rest} Region{mode, fresh, old, count, pending}:
      finish_region(feed(pending, mode, fresh, old, count), T.Empty{})
    case T.Pop{Some{Block{+id, +kind, +text}}, rest} Region{+mode, +fresh, +old, +count, +pending}:
      +joined = pending ++ text
      grow_choice(String.is_empty(pending) && can_stop(mode, kind),
        Region{mode, fresh, old, count, pending}, suffix,
        _ => next(rest, prepare(String.ends_with(joined, "\n"), joined, mode,
          fresh, Block{id, kind, text} <> old, count)))

def finish_pending(region: Region) -> Reparsed:
  match region:
    case Region{mode, fresh, old, count, pending}:
      finish_region(feed(pending, mode, fresh, old, count), T.Empty{})

# Fuel is the old suffix block count. Each continued pass consumes one block.
def grow(fuel: Nat, +suffix: T.Tree<Block>, region: Region) -> Reparsed:
  match fuel:
    case 0n:
      finish_pending(region)
    case 1n+rest:
      grow_popped(T.pop(Block, suffix), region, suffix,
        tree => state => grow(rest, tree, state))

def built_region(assigned: Assigned, +prefix: T.Tree<Block>, +suffix: T.Tree<Block>, count: Nat,
  old_count: Nat) -> Change:
  match assigned:
    case Assigned{+blocks, next}:
      +first = T.count(Block, prefix)
      removed = Nat.sub(old_count, Nat.add(first, T.count(Block, suffix)))
      added = List.length(&2, Block, blocks)
      Change{Document{T.concat(Block, prefix,
        T.concat(Block, T.from_list(~Block, ~block_length, blocks), suffix)), next, count}, first, removed, added}

def rebuild(reparsed: Reparsed, id: Nat, prefix: T.Tree<Block>, old_count: Nat) -> Change:
  match reparsed:
    case Reparsed{fresh, old, suffix, count}:
      built_region(reuse_prefix(fresh, old, id, Nil{}), prefix, suffix, count, old_count)

def update_cut(cut: T.Split<Block>, id: Nat, prefix: T.Tree<Block>, start: Nat, end: Nat, insert: String,
  old_count: Nat) -> Change:
  match cut:
    case T.Split{included_tree, +remaining}:
      +included = T.flatten(Block, included_tree, Nil{})
      +text = Position.replace(source_list(included), start, end, insert)
      initial = prepare(String.is_empty(text) || String.ends_with(text, "\n"), text,
        B.Idle{}, Nil{}, List.reverse(&2, Block, included), 0n)
      rebuild(grow(T.count(Block, remaining), remaining, initial), id, prefix, old_count)

def update_anchor(anchor: T.Split<Block>, id: Nat, start: Nat, +end: Nat, insert: String,
  old_count: Nat) -> Change:
  match anchor:
    case T.Split{+prefix, +tail}:
      +offset = T.length(Block, prefix)
      +through = Nat.add(1n, T.rank(Block, tail, Nat.sub(end, offset), 0n))
      update_cut(T.split(Block, tail, through), id, prefix,
        Nat.sub(start, offset), Nat.sub(end, offset), insert, old_count)

def apply_change(document: Document, +start: Nat, +end: Nat, insert: String) -> Change:
  match document:
    case Document{+blocks, id, reparsed}:
      anchor = Nat.sub(T.rank(Block, blocks, Nat.min(start, end), 0n), 1n)
      update_anchor(T.split(Block, blocks, anchor), id,
        Nat.min(start, end), Nat.max(start, end), insert, T.count(Block, blocks))

def apply(document: Document, start: Nat, end: Nat, insert: String) -> Document:
  changed(apply_change(document, start, end, insert))
