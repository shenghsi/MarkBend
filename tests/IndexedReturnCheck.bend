import Base
import ../src/IndexedReturn.bend as Indexed
import ../src/ListReturn.bend as Legacy
import ../src/Document.bend as D
import ./ListReturnCheck.bend as Edit
import ./DirectCheck.bend as Check

def same(actual: Legacy.Edit, expected: Legacy.Edit) -> Bool:
  match expected:
    case Legacy.Edit{start, end, text}:
      Edit.matches(actual, start, end, text)

def ends(fuel: Nat, +source: String, +document: D.Document,
  +start: Nat, +end: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        Check.check(same(Indexed.plan(document, start, end), Legacy.plan(source, start, end)))
        ends(rest, source, document, start, 1n+end)

def starts(fuel: Nat, +source: String, +document: D.Document,
  +size: Nat, +start: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        ends(1n+size, source, document, start, 0n)
        starts(rest, source, document, size, 1n+start)

def fixture(+source: String) -> IO(Unit):
  +size = D.count_scalars(source, 0n)
  starts(1n+size, source, D.parse(source), size, 0n)

def main() -> IO(Unit):
  do IO<Unit>:
    fixture("")
    fixture("- x")
    fixture("* \t\r\n")
    fixture("+ \t text\r\nnext\n- 中😀")
    fixture("before\r\n- x\n")
    fixture("one\ntwo\r\nthree")
    fixture("```\n- x\n```\n- y")
    fixture("```\n- x\n```\n")
    fixture("~~~\r\n- x\r\n~~~\r\n")
    fixture("~~~\r\n- x")
    fixture("- **中😀**\n\n# h\r\n+ ")
    fixture(" - x\n1. y\n-\n")
    IO.print("Indexed Return matches all legacy edit fields for all fixture selection pairs")
