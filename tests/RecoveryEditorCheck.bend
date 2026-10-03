import Base
import ../src/RecoveryEditor.bend as Bridge
import ../src/RecoveryPlan.bend as Plan
import ../src/RecoveryScan.bend as Scan
import ../src/RecoveryEntry.bend as Entry
import ../src/RecoveryState.bend as Recovery
import ../src/RecoveryLookup.bend as Lookup
import ../src/SaveState.bend as Save
import ../src/DirectState.bend as Editor
import ../src/Utf8.bend as Utf8
import ./Utf8Check.bend as Text
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check

def bytes(value: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match value:
    case Some{data}:
      data
    case None{}:
      [256]

def text() -> String:
  "\u{feff}# 中文😀\r\n\r\n**e\u{301}**\0\n"

def recorded() -> Save.State:
  Save.State{bytes(Utf8.encode(text())), [65, 13, 10], 1n,
    Some{Save.Ticket{0n, [66, 0, 255]}}}

def catalog(value: Maybe<&2, String>) -> Scan.Catalog:
  match value:
    case Some{record}:
      Scan.add(Scan.decoded(Entry.decode(record), "61"), Scan.Catalog{Nil{}, Nil{}})
    case None{}:
      Scan.Catalog{Nil{}, [Scan.Rejected{"61", Scan.InvalidRecord{}}]}

def stored() -> Scan.Catalog:
  catalog(Entry.encode(Entry.Entry{[42], recorded()}))

def fresh(session: Editor.Session, expected: String) -> Bool:
  match session:
    case Editor.Session{snapshot, Nil{}, Nil{}, view, cache, index}:
      Check.snapshot_is(snapshot, expected, 0n, 0n)
    case _:
      False{}

def opened(value: Bridge.Outcome) -> IO(Unit):
  match value:
    case Bridge.Opened{requested, Scan.Catalog{entry <> Nil{}, Nil{}}, +save, +editor}:
      do IO<Unit>:
        Check.check(Save.bytes_equal(requested, [42]))
        Check.check(States.state_equal(save, Save.result(recorded(), 0n, False{})))
        Check.check(Save.dirty(save))
        Check.check(fresh(editor, text()))
        Check.check(Text.encoded(Utf8.encode(Editor.source(Editor.current(editor))), Bridge.current(save)))
        Check.check(Text.text_equal(Editor.source(Editor.current(
          Editor.undo(Editor.edit(editor, 0n, 0n, "X")))), text(), True{}))
        Check.check(Text.text_equal(Editor.source(Editor.current(
          Editor.redo(Editor.undo(Editor.edit(editor, 0n, 0n, "X"))))), "X" ++ text(), True{}))
    case _:
      Check.check(False{})

def clean_open(value: Bridge.Outcome) -> Bool:
  match value:
    case Bridge.Opened{requested, Scan.Catalog{Nil{}, Nil{}}, +save, editor}:
      Save.bytes_equal(requested, [42]) && Bool.not(Save.dirty(save)) &&
        States.state_equal(save, Save.open([65, 13, 10])) && fresh(editor, "A\r\n")
    case _:
      False{}

def pending_open(value: Bridge.Outcome) -> Bool:
  match value:
    case Bridge.Opened{requested, catalog, +save, editor}:
      Save.bytes_equal(requested, [42]) && Save.dirty(save) &&
        States.state_equal(save, Save.result(recorded(), 0n, True{})) && fresh(editor, text())
    case _:
      False{}

def invalid_open(value: Bridge.Outcome) -> Bool:
  match value:
    case Bridge.Blocked{Plan.Plan{requested, Plan.NoMatch{Scan.Catalog{Nil{}, Nil{}}, disk}}}:
      Save.bytes_equal(requested, [42]) && Save.bytes_equal(disk, [255, 0, 13, 10])
    case _:
      False{}

def invalid_restore(value: Bridge.Outcome) -> Bool:
  match value:
    case Bridge.Blocked{Plan.Plan{requested, Plan.Ready{catalog,
      Entry.ForDocument{Recovery.Restored{state}}}}}:
      Save.bytes_equal(requested, [42]) &&
        States.state_equal(state, Save.State{[255, 0], [65], 2n, None{}})
    case _:
      False{}

def conflict(value: Bridge.Outcome) -> Bool:
  match value:
    case Bridge.Blocked{Plan.Plan{requested, Plan.Ready{Scan.Catalog{entry <> Nil{}, Nil{}},
      Entry.ForDocument{Recovery.Conflict{state, disk}}}}}:
      Save.bytes_equal(requested, [42]) && States.state_equal(state, recorded()) &&
        Save.bytes_equal(disk, [88, 0, 255])
    case _:
      False{}

def entry_same(entry: Entry.Entry) -> Bool:
  match entry:
    case Entry.Entry{key, state}:
      Save.bytes_equal(key, [42]) && States.state_equal(state, recorded())

def review(value: Bridge.Outcome) -> Bool:
  match value:
    case Bridge.Blocked{Plan.Plan{requested, Plan.Review{Scan.Catalog{accepted, Nil{}},
      Lookup.Ambiguous{a <> b <> Nil{}}, disk}}}:
      Save.bytes_equal(requested, [42]) && entry_same(a) && entry_same(b) &&
        Nat.is_eq(List.length(&2, Scan.Accepted, accepted), 2n) && Save.bytes_equal(disk, [65, 13, 10])
    case _:
      False{}

def unavailable(value: Bridge.Outcome) -> Bool:
  match value:
    case Bridge.Blocked{Plan.Plan{requested, Plan.Unavailable{"root", Scan.HostFailed{code}, disk}}}:
      Save.bytes_equal(requested, [42]) && U32.is_eq(code, 1) && Save.bytes_equal(disk, [255])
    case _:
      False{}

def model(value: Bridge.Outcome, +expected: String, +expected_save: Save.State) -> Bool:
  match value:
    case Bridge.Opened{requested, Scan.Catalog{Scan.Accepted{"61", entry} <> Nil{}, Nil{}},
      +save, editor}:
      Save.bytes_equal(requested, [42]) && entry_same(entry) &&
        States.state_equal(save, expected_save) &&
        Text.text_equal(Editor.source(Editor.current(editor)), expected, True{}) &&
        Text.encoded(Utf8.encode(expected), Bridge.current(save)) &&
        U32.is_eq(Bool.to_u32(Save.dirty(save)), Bool.to_u32(Save.dirty(expected_save)))
    case _:
      False{}

def rejected_edit(value: Bridge.Outcome) -> Bool:
  match value:
    case Bridge.RejectedEdit{previous, attempted}:
      model(previous, text(), Save.result(recorded(), 0n, False{})) &&
        Text.text_equal(Editor.source(Editor.current(attempted)), "bad", True{})
    case _:
      False{}

def commands() -> IO(Unit):
  +initial = Bridge.open(Plan.prepare(Scan.Completed{stored()}, [42], [65, 13, 10]))
  +restored = Save.result(recorded(), 0n, False{})
  +prefix = "中文😀\n" ++ text()
  +edited = Bridge.edit(initial, 0n, 0n, "中文😀\n")
  +edited_save = Save.edit(restored, bytes(Utf8.encode(prefix)))
  +pending = Bridge.request(edited)
  +pending_save = Save.request(edited_save)
  +later = Bridge.edit(pending, 0n, 0n, "X")
  +later_save = Save.edit(pending_save, bytes(Utf8.encode("X" ++ prefix)))
  +confirmed = Bridge.complete(later, 1n, Save.Confirmed{})
  +confirmed_save = Save.complete(later_save, 1n, Save.Confirmed{})
  do IO<Unit>:
    Check.check(model(edited, prefix, edited_save))
    Check.check(model(Bridge.undo(edited), text(), restored))
    Check.check(model(Bridge.redo(Bridge.undo(edited)), prefix, edited_save))
    Check.check(model(Bridge.edit(edited, 0n, 5n, ""), text(), restored))
    Check.check(model(pending, prefix, pending_save))
    Check.check(model(Bridge.select(pending, 0n, 1n), prefix, pending_save))
    Check.check(model(later, "X" ++ prefix, later_save))
    Check.check(model(Bridge.request(later), "X" ++ prefix, later_save))
    Check.check(model(confirmed, "X" ++ prefix, confirmed_save))
    Check.check(model(Bridge.complete(later, 99n, Save.Confirmed{}), "X" ++ prefix, later_save))
    Check.check(model(Bridge.complete(later, 1n, Save.ReplacementUncertain{}), "X" ++ prefix, later_save))
    Check.check(model(Bridge.complete(later, 1n, Save.OldKept{}), "X" ++ prefix,
      Save.complete(later_save, 1n, Save.OldKept{})))
    Check.check(model(Bridge.undo(confirmed), prefix,
      Save.edit(confirmed_save, bytes(Utf8.encode(prefix)))))
    Check.check(model(Bridge.redo(Bridge.undo(confirmed)), "X" ++ prefix, confirmed_save))
    Check.check(rejected_edit(Bridge.encoded(None{}, initial, [42], stored(), restored, Editor.start("bad"))))

def blocked_commands(value: Bridge.Outcome) -> Bool:
  edited = Bridge.edit(value, 0n, 0n, "X")
  undone = Bridge.undo(edited)
  redone = Bridge.redo(undone)
  pending = Bridge.request(redone)
  invalid_open(Bridge.complete(pending, 0n, Save.Confirmed{}))

def main() -> IO(Unit):
  do IO<Unit>:
    commands()
    opened(Bridge.open(Plan.prepare(Scan.Completed{stored()}, [42], [65, 13, 10])))
    Check.check(pending_open(Bridge.open(Plan.prepare(Scan.Completed{stored()}, [42], [66, 0, 255]))))
    Check.check(clean_open(Bridge.open(Plan.prepare(Scan.Completed{Scan.Catalog{Nil{}, Nil{}}},
      [42], [65, 13, 10]))))
    Check.check(invalid_open(Bridge.open(Plan.prepare(Scan.Completed{Scan.Catalog{Nil{}, Nil{}}},
      [42], [255, 0, 13, 10]))))
    Check.check(blocked_commands(Bridge.open(Plan.prepare(Scan.Completed{Scan.Catalog{Nil{}, Nil{}}},
      [42], [255, 0, 13, 10]))))
    Check.check(invalid_restore(Bridge.open(Plan.Plan{[42], Plan.Ready{Scan.Catalog{Nil{}, Nil{}},
      Entry.ForDocument{Recovery.Restored{Save.State{[255, 0], [65], 2n, None{}}}}}})))
    Check.check(conflict(Bridge.open(Plan.prepare(Scan.Completed{stored()}, [42], [88, 0, 255]))))
    Check.check(review(Bridge.open(Plan.prepare(Scan.Completed{Scan.Catalog{
      [Scan.Accepted{"61", Entry.Entry{[42], recorded()}},
       Scan.Accepted{"62", Entry.Entry{[42], recorded()}}], Nil{}}}, [42], [65, 13, 10]))))
    Check.check(unavailable(Bridge.open(Plan.prepare(Scan.Failed{"root", Scan.HostFailed{1}}, [42], [255]))))
    IO.print("Recovery editor source, baseline, history, and blocked-plan check passed")
