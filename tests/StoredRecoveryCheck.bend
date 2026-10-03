import Base
import ../src/StoredRecovery.bend as Recovery
import ../src/StoredEditor.bend as Editor
import ../src/RecoveryPlan.bend as Plan
import ../src/RecoveryScan.bend as Scan
import ../src/RecoveryEntry.bend as Entry
import ../src/SaveState.bend as Save
import ../src/RecoveryState.bend as Recovered
import ./SaveStateCheck.bend as States
import ./RecoveryEditorCheck.bend as Fixture
import ./StoredEditorCheck.bend as Stored
import ./NativeRecoveryCheck.bend as Native
import ./DirectCheck.bend as Check

def same(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}:
      True{}
    case False{} False{}:
      True{}
    case _ _:
      False{}

def opened(value: Recovery.Outcome, +source: String, +expected: Save.State,
  restored: Bool) -> IO(Unit):
  match value:
    case Recovery.Opened{requested, +catalog, +editor}:
      do IO<Unit>:
        Check.check(Save.bytes_equal(requested, [42]))
        Check.check(Stored.matches(editor, source, expected))
        Check.check(Plan.clean(catalog))
        Check.check(same(Native.owned(catalog, [42]), restored))
        changed : Editor.Session <- Stored.accepted(Editor.edit(editor, 0n, 0n, "X"))
        Check.check(Stored.matches(Editor.undo(changed), source, expected))
    case _:
      Check.check(False{})

def invalid(value: Recovery.Outcome) -> Bool:
  match value:
    case Recovery.Blocked{Plan.Plan{requested, Plan.NoMatch{Scan.Catalog{Nil{}, Nil{}}, bytes}}}:
      Save.bytes_equal(requested, [42]) && Save.bytes_equal(bytes, [255,0])
    case _:
      False{}

def conflict(value: Recovery.Outcome) -> Bool:
  match value:
    case Recovery.Blocked{Plan.Plan{requested, Plan.Ready{catalog,
      Entry.ForDocument{Recovered.Conflict{state, disk}}}}}:
      Save.bytes_equal(requested, [42]) && Native.owned(catalog, [42]) &&
        States.state_equal(state, Native.recorded()) && Save.bytes_equal(disk, [88])
    case _:
      False{}

def unavailable(value: Recovery.Outcome) -> Bool:
  match value:
    case Recovery.Blocked{Plan.Plan{requested,
      Plan.Unavailable{root, Scan.HostFailed{code}, disk}}}:
      Save.bytes_equal(requested, [42]) && String.eq(root, "catalog") &&
        U32.is_eq(code, 19) && Save.bytes_equal(disk, [65])
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    opened(Recovery.open(Plan.prepare(Scan.Completed{Scan.Catalog{[],[]}}, [42], [65,13,10])),
      "A\r\n", Save.open([65,13,10]), False{})
    opened(Recovery.open(Plan.prepare(Scan.Completed{
      Fixture.catalog(Entry.encode(Entry.Entry{[42], Native.recorded()}))}, [42], Native.baseline())),
      Native.original(), Save.result(Native.recorded(), 0n, False{}), True{})
    Check.check(invalid(Recovery.open(Plan.prepare(Scan.Completed{Scan.Catalog{[],[]}}, [42], [255,0]))))
    Check.check(conflict(Recovery.open(Plan.prepare(Scan.Completed{
      Fixture.catalog(Entry.encode(Entry.Entry{[42], Native.recorded()}))}, [42], [88]))))
    Check.check(unavailable(Recovery.open(Plan.prepare(
      Scan.Failed{"catalog", Scan.HostFailed{19}}, [42], [65]))))
    IO.print("Recovery plans with persistent editor storage check passed")
