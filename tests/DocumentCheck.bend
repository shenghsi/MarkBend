import Base
import ../src/Blocks.bend as B
import ../src/Document.bend as D
import ../src/TextPosition.bend as Position
import ../src/BlockIndex.bend as T

def check(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "Document check failed")

def same_pieces(a: List<&2, B.Piece>, b: List<&2, B.Piece>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case B.Piece{x, p} <> rest B.Piece{y, q} <> later:
      D.same_kind(x, y) && String.eq(p, q) && same_pieces(rest, later)
    case _ _:
      False{}

def contains_id(blocks: List<&2, D.Block>, +id: Nat) -> Bool:
  match blocks:
    case Nil{}:
      False{}
    case D.Block{found, kind, text} <> rest:
      Nat.is_eq(found, id) || contains_id(rest, id)

def unique(blocks: List<&2, D.Block>) -> Bool:
  match blocks:
    case Nil{}:
      True{}
    case D.Block{id, kind, text} <> +rest:
      Bool.not(contains_id(rest, id)) && unique(rest)

def matches(document: D.Document, +source: String) -> Bool:
  match document:
    case D.Document{+blocks, next, reparsed}:
      String.eq(D.source(blocks), source) &&
        same_pieces(D.pieces(blocks), B.parse(source)) &&
        unique(T.flatten(D.Block, blocks, Nil{})) && T.valid(~D.Block, ~D.block_length, blocks)

def same_blocks(a: List<&2, D.Block>, b: List<&2, D.Block>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case D.Block{id, kind, text} <> rest D.Block{other, later_kind, later_text} <> later:
      Nat.is_eq(id, other) && D.same_kind(kind, later_kind) &&
        String.eq(text, later_text) && same_blocks(rest, later)
    case _ _:
      False{}

def valid_change(old: D.Document, change: D.Change) -> Bool:
  match old change:
    case D.Document{+before, next, reparsed}
      D.Change{D.Document{+after, later_id, later_parsed}, +first, +removed, +added}:
      +a = T.flatten(D.Block, before, Nil{})
      +b = T.flatten(D.Block, after, Nil{})
      Nat.is_le(Nat.add(first, removed), T.count(D.Block, before)) &&
        Nat.is_le(Nat.add(first, added), T.count(D.Block, after)) &&
        Nat.is_eq(T.count(D.Block, after), Nat.add(Nat.sub(T.count(D.Block, before), removed), added)) &&
        same_blocks(List.take(&2, D.Block, a, first), List.take(&2, D.Block, b, first)) &&
        same_blocks(List.drop(&2, D.Block, a, Nat.add(first, removed)),
          List.drop(&2, D.Block, b, Nat.add(first, added)))

def edit(+doc: D.Document, +source: String, +start: Nat, +end: Nat, +insert: String) -> IO(Unit):
  +change = D.apply_change(doc, start, end, insert)
  check(valid_change(doc, change) &&
    matches(D.changed(change), Position.replace(source, start, end, insert)))

def positions(fuel: Nat, +doc: D.Document, +source: String, +position: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        edit(doc, source, position, position, "😀")
        edit(doc, source, position, position, "\n")
        edit(doc, source, position, position, "```\n")
        edit(doc, source, position, position, "# ")
        edit(doc, source, position, 1n+position, "")
        edit(doc, source, position, 3n+position, "")
        edit(doc, source, position, String.length(source), "")
        edit(doc, source, 3n+position, position, "中文\n")
        positions(rest, doc, source, 1n+position)

def samples(sources: List<&2, String>) -> IO(Unit):
  match sources:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case +source <> rest:
      +doc = D.parse(source)
      do IO<Unit>:
        check(matches(doc, source))
        positions(1n+String.length(source), doc, source, 0n)
        samples(rest)

def ids(blocks: List<&2, D.Block>) -> List<&2, Nat>:
  match blocks:
    case Nil{}:
      Nil{}
    case D.Block{id, kind, text} <> rest:
      id <> ids(rest)

def id_equal(a: List<&2, Nat>, b: List<&2, Nat>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case x <> rest y <> later:
      Nat.is_eq(x, y) && id_equal(rest, later)
    case _ _:
      False{}

def stable(document: D.Document) -> Bool:
  match document:
    case D.Document{blocks, next, reparsed}:
      id_equal(ids(T.flatten(D.Block, blocks, Nil{})), [0n, 1n, 5n, 3n, 4n]) &&
        Nat.is_eq(next, 6n) && Nat.is_eq(reparsed, 5n)

def parsed_count(document: D.Document) -> Nat:
  match document:
    case D.Document{blocks, next, reparsed}:
      reparsed

def sequence_insert(index: Nat) -> String:
  match index:
    case 0n:
      "\n"
    case 1n:
      "```\n"
    case 2n:
      ""
    case _:
      "* 中文\n"

def sequence(fuel: Nat, +doc: D.Document, +source: String, +index: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      +position = Nat.mod(Nat.mul(index, 7n), 1n+String.length(source))
      +end = Nat.add(position, Nat.mod(index, 3n))
      +insert = sequence_insert(Nat.mod(index, 4n))
      +next_source = Position.replace(source, position, end, insert)
      +change = D.apply_change(doc, position, end, insert)
      +next = D.changed(change)
      do IO<Unit>:
        check(valid_change(doc, change))
        check(matches(next, next_source))
        sequence(rest, next, next_source, 1n+index)

def main() -> IO(Unit):
  +large = String.repeat("# h\n\ntext\n\n", 128n)
  +large_doc = D.parse(large)
  do IO<Unit>:
    check(matches(large_doc, large))
    edit(large_doc, large, 0n, 1n, "##")
    edit(large_doc, large, 700n, 703n, "😀\n")
    edit(large_doc, large, 1400n, 1408n, "```\n")
    check(same_pieces(B.parse("# h\n\np\nq\n- a\n1. b\n> c\n```rs\n*literal*\n```\n"), [
      B.Piece{B.Heading{1n}, "# h\n"}, B.Piece{B.Blank{}, "\n"},
      B.Piece{B.Paragraph{}, "p\nq\n"}, B.Piece{B.ListItem{False{}}, "- a\n"},
      B.Piece{B.ListItem{True{}}, "1. b\n"}, B.Piece{B.Quote{}, "> c\n"},
      B.Piece{B.Fence{'`', 3n, True{}}, "```rs\n*literal*\n```\n"}
    ]))
    check(stable(D.apply(D.parse("# a\n\n# b\n\n# c\n"), 7n, 8n, "B")))
    check(Nat.is_eq(parsed_count(D.apply(D.parse("# a\n\n# b\n\n# c\n"), 2n, 3n, "X")), 4n))
    check(matches(D.apply(D.parse("#\n# h\n\ntail"), 1n, 2n, ""), "## h\n\ntail"))
    check(matches(D.apply(D.parse("# a\n\n# b\n\n# c\n"), 0n, 4n, "```\n"),
      "```\n\n# b\n\n# c\n"))
    check(Nat.is_eq(parsed_count(D.apply(D.parse("# a\n\n# b\n\n# c\n"),
      0n, 4n, "```\n")), 14n))
    samples(["", "中文😀\nnext", "a\nb\n\nc\n", "# a\n\n# b\n\n# c\n",
      "- a\n2. b\n> q\n", "```rs\na\n```\ntail", "~~~\na\n~~~\n", "```\na\n",
      "````\n```\nx\n````\n", "a\r\n\r\n> b\r\n", "   # a\n    # b\n",
      "```\na\n``` text\nb\n```\n"])
    sequence(40n, D.parse("# a\n\ntext\n\n```\ncode\n```\n> q\n"),
      "# a\n\ntext\n\n```\ncode\n```\n> q\n", 0n)
    IO.print("Document edit batch passed")
