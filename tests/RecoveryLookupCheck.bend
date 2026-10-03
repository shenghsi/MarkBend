import Base
import ../src/RecoveryLookup.bend as Lookup
import ../src/RecoveryEntry.bend as Entry
import ../src/SaveState.bend as Save
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check

def entry(key: U32, edit: U32) -> Entry.Entry:
  Entry.Entry{[key], Save.edit(Save.open(Nil{}), [edit, 0, 255])}

def same(left: Entry.Entry, right: Entry.Entry) -> Bool:
  match left right:
    case Entry.Entry{lk, ls} Entry.Entry{rk, rs}:
      Save.bytes_equal(lk, rk) && States.state_equal(ls, rs)

def missing(value: Lookup.Selection) -> Bool:
  match value:
    case Lookup.Missing{}:
      True{}
    case _:
      False{}

def unique(value: Lookup.Selection, expected: Entry.Entry) -> Bool:
  match value:
    case Lookup.Unique{found}:
      same(found, expected)
    case _:
      False{}

def invalid(value: Lookup.Selection, requested: List<&2, U32>, expected: Entry.Entry) -> Bool:
  match value:
    case Lookup.InvalidIdentity{actual, entry <> Nil{}}:
      Save.bytes_equal(actual, requested) && same(entry, expected)
    case _:
      False{}

def ambiguous(value: Lookup.Selection, first: Entry.Entry, second: Entry.Entry) -> Bool:
  match value:
    case Lookup.Ambiguous{a <> b <> Nil{}}:
      same(a, first) && same(b, second)
    case _:
      False{}

def filler(count: Nat, entries: List<&2, Entry.Entry>) -> List<&2, Entry.Entry>:
  match count:
    case 0n:
      entries
    case 1n+p:
      filler(p, Con{entry(98, 66), entries})

def main() -> IO(Unit):
  +a = entry(97, 65)
  +b = entry(98, 66)
  +later = entry(97, 67)
  do IO<Unit>:
    Check.check(missing(Lookup.lookup(Nil{}, [97])))
    Check.check(missing(Lookup.lookup([b], [97])))
    Check.check(invalid(Lookup.lookup([a], Nil{}), Nil{}, a))
    Check.check(invalid(Lookup.lookup([a], [256]), [256], a))
    Check.check(unique(Lookup.lookup([a, b], [97]), a))
    Check.check(unique(Lookup.lookup([b, a], [97]), a))
    Check.check(ambiguous(Lookup.lookup([a, b, later], [97]), a, later))
    Check.check(ambiguous(Lookup.lookup([later, b, a], [97]), later, a))
    Check.check(ambiguous(Lookup.lookup([a, a], [97]), a, a))
    Check.check(unique(Lookup.lookup(filler(65536n, [a]), [97]), a))
    IO.print("Recovery exact identity lookup check passed")
