import Base
import ../src/Document.bend as D
import ../src/BlockIndex.bend as T

type Summary is Data:
  Summary{blocks: Nat, scalars: Nat, reparsed: Nat}

def summary(doc: D.Document) -> Summary:
  match doc:
    case D.Document{+blocks, next, reparsed}:
      Summary{T.count(D.Block, blocks), T.length(D.Block, blocks), reparsed}

def report(result: Summary, start: Nat, stop: Nat, label: String) -> IO(Unit):
  match result:
    case Summary{blocks, scalars, reparsed}:
      IO.print(label ++ ": scalars=" ++ Nat.show(scalars) ++
        " blocks=" ++ Nat.show(blocks) ++ " parsed_scalars=" ++ Nat.show(reparsed) ++
        " elapsed_ms=" ++ Nat.show(Nat.sub(stop, start)))

def open_bench(+text: String) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    result : D.Document = D.parse(text)
    stop : Nat <- IO.now()
    report(summary(result), start, stop, "open")

def edit_at(+doc: D.Document, +position: Nat, label: String) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    result : D.Document = D.apply(doc, position, 1n+position, "X")
    stop : Nat <- IO.now()
    report(summary(result), start, stop, label)

def edit_bench(+text: String) -> IO(Unit):
  +doc = D.parse(text)
  +end = String.length(text)
  do IO<Unit>:
    edit_at(doc, 2n, "edit_near_start")
    edit_at(doc, Nat.div(end, 2n), "edit_middle")
    edit_at(doc, Nat.sub(end, 3n), "edit_near_end")

def head(text: String) -> Char & String:
  match text:
    case SCon{char, rest}:
      (char, rest)
    case SNil{}:
      (' ', SNil{})

def cyclic_head(text: String, unit: String) -> Char & String:
  match text:
    case SCon{char, rest}:
      (char, rest)
    case SNil{}:
      head(unit)

def with_head(value: Char & String, more: Char -> String -> String) -> String:
  match value:
    case (char, rest):
      more(char, rest)

def sample_loop(fuel: Nat, current: String, +unit: String, reversed: String) -> String:
  match fuel:
    case 0n:
      String.reverse(reversed)
    case 1n+remaining:
      with_head(cyclic_head(current, unit), char => rest =>
        sample_loop(remaining, rest, unit, SCon{char, reversed}))

def sample(size: Nat) -> String:
  +unit = {"# Heading\n\nThis paragraph has **strong** text and *emphasis*.\n\n" : String}
  sample_loop(size, unit, unit, SNil{})

def repeat(fuel: Nat, +text: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        open_bench(text)
        edit_bench(text)
        repeat(rest, text)

def main() -> IO(Unit):
  do IO<Unit>:
    +small : String = sample(102400n)
    +large : String = sample(1048576n)
    IO.print("ASCII fixture; scalar count equals UTF-8 byte count")
    repeat(20n, small)
    repeat(20n, large)
