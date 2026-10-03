import Base
import ../src/RecoveryEditor.bend as Bridge
import ../src/RecoveryPlan.bend as Plan
import ../src/RecoveryScan.bend as Scan
import ../src/DirectState.bend as Editor
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Bytes
import ./DirectCheck.bend as Check

def count(bytes: List<&2, U32>, acc: Nat) -> Nat:
  match bytes:
    case Nil{}:
      acc
    case head <> rest:
      count(rest, 1n+acc)

def correct(value: Bridge.Outcome) -> Bool:
  match value:
    case Bridge.Opened{requested, catalog,
      Save.State{88 <> current, +saved, 1n, Some{Save.Ticket{0n, pending}}}, editor}:
      Save.bytes_equal(requested, [42]) && Save.bytes_equal(current, saved) &&
        Save.bytes_equal(pending, saved) && Nat.is_eq(count(saved, 0n), 1048576n)
    case _:
      False{}

def sample(+value: Bridge.Outcome, number: Nat) -> IO(Unit):
  match value:
    case Bridge.Opened{requested, catalog, save, editor}:
      do IO<Unit>:
        +start : Nat <- IO.now()
        next : Editor.Session = Editor.edit(editor, 0n, 0n, "X")
        +edited : Nat <- IO.now()
        result : Bridge.Outcome = Bridge.sync(value, next)
        +synced : Nat <- IO.now()
        Check.check(correct(result))
        IO.print("save_sync sample=" ++ Nat.show(number) ++
          " editor_ms=" ++ Nat.show(Nat.sub(edited, start)) ++
          " sync_ms=" ++ Nat.show(Nat.sub(synced, edited)) ++
          " total_ms=" ++ Nat.show(Nat.sub(synced, start)))
    case _:
      Check.check(False{})

def repeat(fuel: Nat, +value: Bridge.Outcome, +number: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("One-MiB recovery editor save synchronization benchmark passed")
    case 1n+rest:
      do IO<Unit>:
        sample(value, number)
        repeat(rest, value, 1n+number)

def main() -> IO(Unit):
  +source = Fixture.sample(1048576n)
  +value = Bridge.request(Bridge.open(Plan.prepare(Scan.Completed{Scan.Catalog{Nil{}, Nil{}}},
    [42], Bytes.bytes(Utf8.encode(source)))))
  repeat(20n, value, 1n)
