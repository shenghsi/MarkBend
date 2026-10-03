import Base
import ../src/Document.bend as D
import ../src/BlockIndex.bend as Index
import ./DocumentBench.bend as Fixture
import ./DocumentCheck.bend as Check

def report(change: D.Change, label: String) -> IO(Unit):
  match change:
    case D.Change{D.Document{blocks, next, reparsed}, first, removed, added}:
      IO.print(label ++ " first=" ++ Nat.show(first) ++ " removed=" ++ Nat.show(removed) ++
        " added=" ++ Nat.show(added) ++ " blocks=" ++ Nat.show(Index.count(D.Block, blocks)) ++
        " parsed_scalars=" ++ Nat.show(reparsed))

def sample(+document: D.Document, label: String, start: Nat, end: Nat, text: String) -> IO(Unit):
  +change = D.apply_change(document, start, end, text)
  do IO<Unit>:
    Check.check(Check.valid_change(document, change))
    report(change, label)

def main() -> IO(Unit):
  +document = D.parse(Fixture.sample(1048576n))
  do IO<Unit>:
    sample(document, "near_start", 2n, 3n, "X")
    sample(document, "middle", 524288n, 524289n, "X")
    sample(document, "near_end", 1048574n, 1048575n, "X")
    sample(document, "open_fence", 0n, 4n, "```rs\n")
    IO.print("One-MiB changed block ranges passed")
