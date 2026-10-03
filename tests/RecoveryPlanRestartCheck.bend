import Base
import ../src/RecoveryPlan.bend as Plan
import ../src/RecoveryScan.bend as Scan
import ../src/RecoveryEntry.bend as Entry
import ../src/RecoveryState.bend as Recovery
import ../src/RecoveryLookup.bend as Lookup
import ../src/SaveState.bend as Save
import ./RecoveryEntryRestartCheck.bend as Identity
import ./RecoveryLargeRestartCheck.bend as Large
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check
import ./RecoveryRestartCheck.bend as Restart

def write_record(value: Maybe<&2, String>, +atomic: String, +root: String) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Catalog record encoding failed")
    case Some{text}:
      do IO<Unit>:
        Restart.write_bytes(root ++ "/catalog/entry/document", [0])
        saved : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(atomic, ["--save", root ++ "/catalog/entry"], text, 4096, 30000))
        Restart.process_ok(saved)
        IO.die(Unit, 79, "Catalog writer stopped after durable record")

def persist(+atomic: String, identity_host: String, +root: String) -> IO(Unit):
  do IO<Unit>:
    Identity.write_source(atomic, root ++ "/a")
    Identity.write_source(atomic, root ++ "/b")
    key : List<&2, U32> <- Identity.identity(identity_host, root ++ "/a/document")
    write_record(Entry.encode(Entry.Entry{key, Large.recorded()}), atomic, root)

def accepted(entries: List<&2, Scan.Accepted>, key: List<&2, U32>) -> Bool:
  match entries:
    case Scan.Accepted{"656e747279", entry} <> Nil{}:
      Identity.matches(entry, key)
    case _:
      False{}

def catalog(value: Scan.Catalog, key: List<&2, U32>, review: Bool) -> Bool:
  match value review:
    case Scan.Catalog{entries, Nil{}} False{}:
      accepted(entries, key)
    case Scan.Catalog{entries, Scan.Rejected{"626164", Scan.InvalidRecord{}} <> Nil{}} True{}:
      accepted(entries, key)
    case _ _:
      False{}

def correct(mode: String, value: Plan.Plan, +owner_key: List<&2, U32>,
  +expected: List<&2, U32>) -> Bool:
  match mode value:
    case "owner" Plan.Plan{requested, Plan.Ready{entries,
      Entry.ForDocument{Recovery.Restored{state}}}}:
      Save.bytes_equal(requested, expected) && Save.bytes_equal(expected, owner_key) &&
        catalog(entries, owner_key, False{}) &&
        States.state_equal(state, Save.result(Large.recorded(), 0n, False{}))
    case "other" Plan.Plan{requested, Plan.NoMatch{entries, disk}}:
      Save.bytes_equal(requested, expected) && Bool.not(Save.bytes_equal(expected, owner_key)) &&
        catalog(entries, owner_key, False{}) && Save.bytes_equal(disk, Large.bytes(65))
    case "conflict" Plan.Plan{requested, Plan.Ready{entries,
      Entry.ForDocument{Recovery.Conflict{recorded, disk}}}}:
      Save.bytes_equal(requested, expected) && Save.bytes_equal(expected, owner_key) &&
        catalog(entries, owner_key, False{}) && States.state_equal(recorded, Large.recorded()) &&
        Save.bytes_equal(disk, Large.bytes(88))
    case "review" Plan.Plan{requested, Plan.Review{entries, Lookup.Unique{entry}, disk}}:
      Save.bytes_equal(requested, expected) && Save.bytes_equal(expected, owner_key) &&
        catalog(entries, owner_key, True{}) && Identity.matches(entry, owner_key) &&
        Save.bytes_equal(disk, Large.bytes(88))
    case _ _:
      False{}

def read_result(result: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  outcome: Scan.Outcome, +requested: List<&2, U32>, owner_key: List<&2, U32>,
  mode: String) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        disk : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        Check.check(correct(mode, Plan.prepare(outcome, requested, disk), owner_key, requested))
        IO.print("Real identity, catalog, and one-MiB recovery plan restart check passed")

def run(directory_host: String, +identity_host: String, +root: String, +mode: String) -> IO(Unit):
  do IO<Unit>:
    owner_key : List<&2, U32> <- Identity.identity(identity_host, root ++ "/a/document")
    requested : List<&2, U32> <- Identity.identity(identity_host,
      Identity.source_path(Bool.not(String.eq(mode, "other")), root))
    outcome : Scan.Outcome <- Scan.scan(directory_host, root ++ "/catalog")
    file : File <- IO.try(File, File.open(
      Identity.source_path(Bool.not(String.eq(mode, "other")), root), "r"))
    result : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 1048577)
    read_result(result, outcome, requested, owner_key, mode)

def dispatch(mode: String, directory_host: String, identity_host: String,
  root: String, atomic: String) -> IO(Unit):
  match mode:
    case "write":
      persist(atomic, identity_host, root)
    case mode:
      run(directory_host, identity_host, root, mode)

def main() -> IO(Unit):
  do IO<Unit>:
    directory_host : String <- IO.try(String, IO.get_env("MARKBEND_DIRECTORY_HOST"))
    identity_host : String <- IO.try(String, IO.get_env("MARKBEND_IDENTITY_HOST"))
    root : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_DIRECTORY"))
    mode : String <- IO.try(String, IO.get_env("MARKBEND_PLAN_MODE"))
    atomic : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    dispatch(mode, directory_host, identity_host, root, atomic)
