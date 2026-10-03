import Base
import ../src/AppRecovery.bend as Bridge
import ../src/InitialOpen.bend as Initial
import ../src/ResolvedOpen.bend as Resolved
import ../src/AppDocument.bend as App
import ../src/RecoveryPlan.bend as Plan
import ../src/RecoveryScan.bend as Scan
import ../src/RecoveryEntry.bend as Entry
import ../src/RecoveryState.bend as Recovery
import ../src/RecoveryLookup.bend as Lookup
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Fixture
import ./StoredEditorCheck.bend as Stored
import ./SaveStateCheck.bend as States
import ./Utf8Check.bend as Text
import ./DirectCheck.bend as Check
import ./RecoveryLookupCheck.bend as Entries

def key() -> List<&2, U32>:
  Fixture.bytes(Utf8.encode("PATH1:/fixture/中文.md"))

def loaded(value: Initial.Outcome) -> IO(Initial.Initial):
  match value:
    case Initial.Opened{value}:
      IO.pure(Initial.Initial, value)
    case _:
      IO.die(Initial.Initial, 1, "Initial recovery fixture failed")

def initial(disk: List<&2, U32>) -> IO(Initial.Initial):
  loaded(Initial.decode(Resolved.Raw{"alias.md",
    Fixture.bytes(Utf8.encode("/fixture/中文.md")), key(), disk}))

def destination(value: App.Destination) -> Bool:
  match value:
    case App.Resolved{requested, path, identity}:
      String.eq(requested, "alias.md") && String.eq(path, "/fixture/中文.md") &&
        Save.bytes_equal(identity, key())
    case _:
      False{}

def catalog(state: Save.State) -> Scan.Catalog:
  Fixture.catalog(Entry.encode(Entry.Entry{key(), state}))

def same_accepted(left: List<&2, Scan.Accepted>, right: List<&2, Scan.Accepted>) -> Bool:
  match left right:
    case Nil{} Nil{}:
      True{}
    case Scan.Accepted{name, entry} <> rest Scan.Accepted{wanted, expected} <> more:
      String.eq(name, wanted) && Entries.same(entry, expected) && same_accepted(rest, more)
    case _ _:
      False{}

def same_catalog(left: Scan.Catalog, right: Scan.Catalog) -> Bool:
  match left right:
    case Scan.Catalog{entries, Nil{}} Scan.Catalog{expected, Nil{}}:
      same_accepted(entries, expected)
    case _ _:
      False{}

def same_entries(left: List<&2, Entry.Entry>, right: List<&2, Entry.Entry>) -> Bool:
  match left right:
    case Nil{} Nil{}:
      True{}
    case entry <> rest expected <> more:
      Entries.same(entry, expected) && same_entries(rest, more)
    case _ _:
      False{}

def opened(value: Bridge.Outcome, +disk: List<&2, U32>, source: String,
  expected: Save.State, wanted: Scan.Catalog) -> IO(Unit):
  match value:
    case Bridge.Opened{App.Document{path, session}, observed, +entries}:
      do IO<Unit>:
        Check.check(destination(path))
        Check.check(Save.bytes_equal(observed, disk))
        Check.check(Stored.matches(session, source, expected))
        Check.check(Plan.clean(entries))
        Check.check(same_catalog(entries, wanted))
    case _:
      Check.check(False{})

def blocked(value: Bridge.Outcome, +disk: List<&2, U32>, source: String,
  expected: Plan.Decision -> Bool) -> IO(Unit):
  match value:
    case Bridge.Blocked{Initial.Initial{App.Document{path, session}, observed},
      Plan.Plan{requested, decision}}:
      do IO<Unit>:
        Check.check(destination(path))
        Check.check(Save.bytes_equal(observed, disk))
        Check.check(Stored.matches(session, source, Save.open(disk)))
        Check.check(Save.bytes_equal(requested, key()))
        Check.check(expected(decision))
    case _:
      Check.check(False{})

def conflict(value: Plan.Decision) -> Bool:
  match value:
    case Plan.Ready{+entries,
      Entry.ForDocument{Recovery.Conflict{state, disk}}}:
      same_catalog(entries, catalog(Fixture.recorded())) &&
        States.state_equal(state, Fixture.recorded()) && Save.bytes_equal(disk, [88])
    case _:
      False{}

def invalid(value: Plan.Decision) -> Bool:
  match value:
    case Plan.Ready{entries,
      Entry.ForDocument{Recovery.Restored{state}}}:
      same_catalog(entries, catalog(Save.State{[255], [65,13,10], 0n, None{}})) &&
        States.state_equal(state, Save.State{[255], [65,13,10], 0n, None{}})
    case _:
      False{}

def two(first: Scan.Catalog, second: Scan.Catalog) -> Scan.Catalog:
  match first second:
    case Scan.Catalog{entry <> Nil{}, Nil{}}
      Scan.Catalog{Scan.Accepted{name, other} <> Nil{}, Nil{}}:
      Scan.Catalog{[entry, Scan.Accepted{"62", other}], Nil{}}
    case _ _:
      Scan.Catalog{Nil{}, [Scan.Rejected{"fixture", Scan.InvalidRecord{}}]}

def duplicate() -> Scan.Catalog:
  two(catalog(Fixture.recorded()), catalog(Save.edit(Fixture.recorded(), [90])))

def duplicate_review(value: Plan.Decision) -> Bool:
  match value:
    case Plan.Review{catalog,
      Lookup.Ambiguous{entries}, disk}:
      same_catalog(catalog, duplicate()) &&
        same_entries(entries, Scan.entries(duplicate())) && Save.bytes_equal(disk, [65,13,10])
    case _:
      False{}

def rejected_review(value: Plan.Decision) -> Bool:
  match value:
    case Plan.Review{Scan.Catalog{Nil{},
      Scan.Rejected{"bad", Scan.InvalidRecord{}} <> Nil{}}, Lookup.Missing{}, disk}:
      Save.bytes_equal(disk, [65,13,10])
    case _:
      False{}

def unavailable(value: Plan.Decision) -> Bool:
  match value:
    case Plan.Unavailable{"catalog", Scan.HostFailed{19}, disk}:
      Save.bytes_equal(disk, [65,13,10])
    case _:
      False{}

def same_destination(actual: App.Destination, expected: App.Destination) -> Bool:
  match actual expected:
    case App.Untitled{} App.Untitled{}:
      True{}
    case App.Requested{path} App.Requested{wanted}:
      String.eq(path, wanted)
    case _ _:
      False{}

def unresolved(value: Bridge.Outcome, expected: App.Destination) -> IO(Unit):
  match value:
    case Bridge.Unresolved{Initial.Initial{App.Document{actual, session}, disk}}:
      do IO<Unit>:
        Check.check(Stored.matches(session, "A\r\n", Save.open([65,13,10])))
        Check.check(Save.bytes_equal(disk, [65,13,10]))
        Check.check(same_destination(actual, expected))
    case _:
      Check.check(False{})

def unresolved_inputs(base: Initial.Initial) -> IO(Unit):
  match base:
    case Initial.Initial{App.Document{path, +session}, +disk}:
      do IO<Unit>:
        unresolved(Bridge.prepare(Initial.Initial{App.Document{App.Untitled{}, session}, disk},
          Scan.Completed{Scan.Catalog{[],[]}}), App.Untitled{})
        unresolved(Bridge.prepare(Initial.Initial{App.Document{App.Requested{"alias.md"}, session}, disk},
          Scan.Completed{Scan.Catalog{[],[]}}), App.Requested{"alias.md"})

def main() -> IO(Unit):
  do IO<Unit>:
    +base : Initial.Initial <- initial([65,13,10])
    opened(Bridge.prepare(base, Scan.Completed{Scan.Catalog{[],[]}}),
      [65,13,10], "A\r\n", Save.open([65,13,10]), Scan.Catalog{[],[]})
    opened(Bridge.prepare(base, Scan.Completed{catalog(Fixture.recorded())}),
      [65,13,10], Fixture.text(), Save.result(Fixture.recorded(), 0n, False{}), catalog(Fixture.recorded()))
    +other : Scan.Catalog = Fixture.catalog(Entry.encode(Entry.Entry{[99], Fixture.recorded()}))
    opened(Bridge.prepare(base, Scan.Completed{other}),
      [65,13,10], "A\r\n", Save.open([65,13,10]), other)
    +pending : Save.State = Save.State{Fixture.bytes(Utf8.encode(Fixture.text())),
      [66], 2n, Some{Save.Ticket{1n, [65,13,10]}}}
    opened(Bridge.prepare(base, Scan.Completed{catalog(pending)}),
      [65,13,10], Fixture.text(), Save.result(pending, 1n, True{}), catalog(pending))
    changed : Initial.Initial <- initial([88])
    blocked(Bridge.prepare(changed, Scan.Completed{catalog(Fixture.recorded())}), [88], "X", conflict)
    blocked(Bridge.prepare(base, Scan.Completed{catalog(Save.State{[255], [65,13,10], 0n, None{}})}),
      [65,13,10], "A\r\n", invalid)
    blocked(Bridge.prepare(base, Scan.Completed{duplicate()}),
      [65,13,10], "A\r\n", duplicate_review)
    blocked(Bridge.prepare(base, Scan.Completed{Scan.Catalog{[], [Scan.Rejected{"bad", Scan.InvalidRecord{}}]}}),
      [65,13,10], "A\r\n", rejected_review)
    blocked(Bridge.prepare(base, Scan.Failed{"catalog", Scan.HostFailed{19}}),
      [65,13,10], "A\r\n", unavailable)
    unresolved_inputs(base)
    IO.print("Initial resolved observation and recovery destination checks passed")
