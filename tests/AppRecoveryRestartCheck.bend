import Base
import ../src/InitialFile.bend as Reader
import ../src/InitialOpen.bend as Initial
import ../src/AppRecovery.bend as Bridge
import ../src/AppDocument.bend as App
import ../src/RecoveryScan.bend as Scan
import ../src/RecoveryPlan.bend as Plan
import ../src/RecoveryLookup.bend as Lookup
import ../src/RecoveryEntry.bend as Entry
import ../src/RecoveryState.bend as Recovery
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Fixture
import ./RecoveryRestartCheck.bend as Writer
import ./StoredEditorCheck.bend as Stored
import ./SaveStateCheck.bend as States
import ./AppRecoveryCheck.bend as Model
import ./DirectCheck.bend as Check

def recorded() -> Save.State:
  Save.State{Fixture.bytes(Utf8.encode(Fixture.text())), [65,13,10], 2n,
    Some{Save.Ticket{1n, [66,13,10]}}}

def other_recorded() -> Save.State:
  Save.edit(recorded(), [90])

def canonical(+root: String, mode: String) -> String:
  match mode:
    case "other":
      root ++ "/source/other.md"
    case _:
      root ++ "/source/中文 😀.md"

def requested(root: String, mode: String) -> String:
  match mode:
    case "other":
      root ++ "/other-alias.md"
    case _:
      root ++ "/alias.md"

def owner_key(root: String) -> List<&2, U32>:
  Fixture.bytes(Utf8.encode("PATH1:" ++ canonical(root, "owner")))

def destination(value: App.Destination, +root: String, +mode: String) -> Bool:
  match value:
    case App.Resolved{actual, path, identity}:
      String.eq(actual, requested(root, mode)) && String.eq(path, canonical(root, mode)) &&
        Save.bytes_equal(identity, Fixture.bytes(Utf8.encode("PATH1:" ++ canonical(root, mode))))
    case _:
      False{}

def expected_catalog(root: String) -> Scan.Catalog:
  Scan.Catalog{[Scan.Accepted{"656e747279", Entry.Entry{owner_key(root), recorded()}}], []}

def save_record(value: Maybe<&2, String>, +atomic: String, +path: String) -> IO(Unit):
  match value:
    case Some{text}:
      do IO<Unit>:
        Writer.write_bytes(path ++ "/document", [0])
        result : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(atomic, ["--save", path], text, 4096, 30000))
        Writer.process_ok(result)
        IO.die(Unit, 79, "Resolved recovery writer stopped after durable record")
    case None{}:
      IO.die(Unit, 1, "Resolved recovery record encoding failed")

def choose_record(duplicate: Bool) -> Save.State:
  match duplicate:
    case True{}: other_recorded()
    case False{}: recorded()

def choose_name(duplicate: Bool) -> String:
  match duplicate:
    case True{}: "duplicate"
    case False{}: "entry"

def persist(value: Initial.Outcome, atomic: String, +root: String, +mode: String) -> IO(Unit):
  match value:
    case Initial.Opened{Initial.Initial{App.Document{+path, session}, disk}}:
      match path:
        case App.Resolved{actual, resolved, identity}:
          do IO<Unit>:
            Check.check(destination(path, root, "owner"))
            Check.check(Save.bytes_equal(disk, [65,13,10]))
            save_record(Entry.encode(Entry.Entry{identity,
              choose_record(String.eq(mode, "duplicate-write"))}), atomic,
              root ++ "/catalog/" ++ choose_name(String.eq(mode, "duplicate-write")))
        case _:
          Check.check(False{})
    case _:
      Check.check(False{})

def disk(mode: String) -> List<&2, U32>:
  match mode:
    case "pending": [66,13,10]
    case "conflict": [88,13,10]
    case "review": [88,13,10]
    case _: [65,13,10]

def disk_text(mode: String) -> String:
  match mode:
    case "pending": "B\r\n"
    case "conflict": "X\r\n"
    case "review": "X\r\n"
    case _: "A\r\n"

def recovered_state(mode: String) -> Save.State:
  match mode:
    case "other": Save.open([65,13,10])
    case _: Save.State{Fixture.bytes(Utf8.encode(Fixture.text())), disk(mode), 2n, None{}}

def recovered_text(mode: String) -> String:
  match mode:
    case "other": "A\r\n"
    case _: Fixture.text()

def duplicate_catalog(observed_catalog: Scan.Catalog, +root: String) -> Bool:
  match observed_catalog:
    case Scan.Catalog{+a <> +b <> Nil{}, Nil{}}:
      (Model.same_accepted([a,b], [Scan.Accepted{"656e747279", Entry.Entry{owner_key(root), recorded()}},
        Scan.Accepted{"6475706c6963617465", Entry.Entry{owner_key(root), other_recorded()}}]) ||
       Model.same_accepted([a,b], [Scan.Accepted{"6475706c6963617465", Entry.Entry{owner_key(root), other_recorded()}},
        Scan.Accepted{"656e747279", Entry.Entry{owner_key(root), recorded()}}]))
    case _:
      False{}

def review_catalog(observed_catalog: Scan.Catalog, root: String) -> Bool:
  match observed_catalog:
    case Scan.Catalog{entries, Scan.Rejected{"626164", Scan.InvalidRecord{}} <> Nil{}}:
      Model.same_catalog(Scan.Catalog{entries, []}, expected_catalog(root))
    case _:
      False{}

def valid_catalog(observed_catalog: Scan.Catalog, root: String, mode: String) -> Bool:
  match mode:
    case "duplicate": duplicate_catalog(observed_catalog, root)
    case "review": review_catalog(observed_catalog, root)
    case _: Model.same_catalog(observed_catalog, expected_catalog(root))

def conflict_decision(value: Plan.Decision, catalog: Scan.Catalog) -> Bool:
  match value:
    case Plan.Ready{entries, Entry.ForDocument{Recovery.Conflict{state, observed}}}:
      Model.same_catalog(entries, catalog) && States.state_equal(state, recorded()) &&
        Save.bytes_equal(observed, disk("conflict"))
    case _:
      False{}

def review_decision(value: Plan.Decision, +root: String) -> Bool:
  match value:
    case Plan.Review{Scan.Catalog{entries, rejected}, Lookup.Unique{entry}, observed}:
      valid_catalog(Scan.Catalog{entries, rejected}, root, "review") &&
        Model.same_entries([entry], Scan.entries(expected_catalog(root))) &&
        Save.bytes_equal(observed, disk("review"))
    case _:
      False{}

def duplicate_decision(value: Plan.Decision, +catalog: Scan.Catalog) -> Bool:
  match value:
    case Plan.Review{entries, Lookup.Ambiguous{owners}, observed}:
      Model.same_catalog(entries, catalog) && Model.same_entries(owners, Scan.entries(catalog)) &&
        Save.bytes_equal(observed, disk("duplicate"))
    case _:
      False{}

def blocked_decision(value: Plan.Decision, root: String, mode: String,
  catalog: Scan.Catalog) -> Bool:
  match mode:
    case "conflict": conflict_decision(value, catalog)
    case "review": review_decision(value, root)
    case "duplicate": duplicate_decision(value, catalog)
    case _: False{}

def checked(value: Bridge.Outcome, +root: String, +mode: String, +catalog: Scan.Catalog) -> IO(Unit):
  match value:
    case Bridge.Opened{App.Document{path, session}, observed, entries}:
      do IO<Unit>:
        Check.check(String.eq(mode, "owner") || String.eq(mode, "other") || String.eq(mode, "pending"))
        Check.check(destination(path, root, mode))
        Check.check(Save.bytes_equal(observed, disk(mode)))
        Check.check(Model.same_catalog(entries, catalog))
        Check.check(Stored.matches(session, recovered_text(mode), recovered_state(mode)))
    case Bridge.Blocked{Initial.Initial{App.Document{path, session}, observed}, Plan.Plan{identity, decision}}:
      do IO<Unit>:
        Check.check(destination(path, root, mode))
        Check.check(Save.bytes_equal(observed, disk(mode)))
        Check.check(Stored.matches(session, disk_text(mode), Save.open(disk(mode))))
        Check.check(Save.bytes_equal(identity, owner_key(root)))
        Check.check(blocked_decision(decision, root, mode, catalog))
    case _:
      Check.check(False{})

def scanned(value: Scan.Outcome, +initial: Initial.Initial, +root: String, +mode: String) -> IO(Unit):
  match value:
    case Scan.Completed{+catalog}:
      do IO<Unit>:
        Check.check(valid_catalog(catalog, root, mode))
        checked(Bridge.prepare(initial, Scan.Completed{catalog}), root, mode, catalog)
        IO.print("Real resolved file and recovery catalog restart check passed: " ++ mode)
    case _:
      Check.check(False{})

def read_result(value: Initial.Outcome, directory: String, +root: String, +mode: String) -> IO(Unit):
  match value:
    case Initial.Opened{initial}:
      do IO<Unit>:
        result : Scan.Outcome <- Scan.scan(directory, root ++ "/catalog")
        scanned(result, initial, root, mode)
    case _:
      Check.check(False{})

def run(+mode: String, atomic: String, directory: String, +root: String) -> IO(Unit):
  match mode:
    case "write":
      do IO<Unit>:
        value : Initial.Outcome <- Reader.read(requested(root, "owner"))
        persist(value, atomic, root, mode)
    case "duplicate-write":
      do IO<Unit>:
        value : Initial.Outcome <- Reader.read(requested(root, "owner"))
        persist(value, atomic, root, mode)
    case _:
      do IO<Unit>:
        value : Initial.Outcome <- Reader.read(requested(root, mode))
        read_result(value, directory, root, mode)

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> mode <> atomic <> directory <> root <> Nil{}:
      run(mode, atomic, directory, root)
    case _:
      IO.die(Unit, 1, "Supply mode, atomic host, catalog host, and fixture root")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
