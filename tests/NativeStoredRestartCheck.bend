import Base
import ../src/StoredRecovery.bend as Recovery
import ../src/StoredEditor.bend as Editor
import ../src/RecoveryPlan.bend as Plan
import ../src/RecoveryScan.bend as Scan
import ../src/SaveState.bend as Save
import ./NativeRecoveryRestartCheck.bend as Writer
import ./NativeRecoveryCheck.bend as Fixture
import ./NativeStoredCheck.bend as Native
import ./StoredEditorCheck.bend as Stored
import ./RecoveryEntryRestartCheck.bend as Identity
import ./DirectCheck.bend as Check

def opened(value: Recovery.Outcome, +expected: List<&2, U32>) -> IO(Unit):
  match value:
    case Recovery.Opened{requested, catalog, +editor}:
      do IO<Unit>:
        Check.check(Save.bytes_equal(requested, expected))
        Check.check(Fixture.owned(catalog, expected))
        Check.check(Stored.matches(editor, Fixture.original(),
          Save.result(Fixture.recorded(), 0n, False{})))
        Native.start(Editor.request(editor))
    case _:
      Check.check(False{})

def source(result: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  outcome: Scan.Outcome, +requested: List<&2, U32>) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        disk : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        opened(Recovery.open(Plan.prepare(outcome, requested, disk)), requested)

def read(directory_host: String, identity_host: String, +root: String) -> IO(Unit):
  do IO<Unit>:
    requested : List<&2, U32> <- Identity.identity(identity_host, root ++ "/source/document")
    outcome : Scan.Outcome <- Scan.scan(directory_host, root ++ "/catalog")
    file : File <- IO.try(File, File.open(root ++ "/source/document", "r"))
    result : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 7)
    source(result, outcome, requested)

def run(mode: String, atomic: String, identity: String, directory: String, root: String) -> IO(Unit):
  match mode:
    case "write":
      Writer.persist(atomic, identity, root)
    case "read":
      read(directory, identity, root)
    case _:
      IO.die(Unit, 1, "Invalid persistent restart mode")

def main() -> IO(Unit):
  do IO<Unit>:
    mode : String <- IO.try(String, IO.get_env("MARKBEND_NATIVE_RECOVERY_MODE"))
    atomic : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    identity : String <- IO.try(String, IO.get_env("MARKBEND_IDENTITY_HOST"))
    directory : String <- IO.try(String, IO.get_env("MARKBEND_DIRECTORY_HOST"))
    root : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_DIRECTORY"))
    run(mode, atomic, identity, directory, root)
