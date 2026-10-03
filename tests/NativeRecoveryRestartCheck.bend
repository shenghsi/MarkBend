import Base
import ../src/RecoveryEditor.bend as Bridge
import ../src/RecoveryPlan.bend as Plan
import ../src/RecoveryScan.bend as Scan
import ../src/RecoveryEntry.bend as Entry
import ./NativeRecoveryCheck.bend as Native
import ./RecoveryEntryRestartCheck.bend as Identity
import ./RecoveryPlanRestartCheck.bend as Writer
import ./RecoveryRestartCheck.bend as Restart

def persist(+atomic: String, identity_host: String, +root: String) -> IO(Unit):
  do IO<Unit>:
    Restart.write_bytes(root ++ "/source/document", Native.baseline())
    synced : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(atomic, ["--sync", root ++ "/source"], "", 4096, 30000))
    Restart.process_ok(synced)
    requested : List<&2, U32> <- Identity.identity(identity_host, root ++ "/source/document")
    Writer.write_record(Entry.encode(Entry.Entry{requested, Native.recorded()}), atomic, root)

def source(result: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  outcome: Scan.Outcome, requested: List<&2, U32>) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        disk : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        Native.open(Bridge.request(Bridge.open(Plan.prepare(outcome, requested, disk))))

def read(directory_host: String, identity_host: String, +root: String) -> IO(Unit):
  do IO<Unit>:
    requested : List<&2, U32> <- Identity.identity(identity_host, root ++ "/source/document")
    outcome : Scan.Outcome <- Scan.scan(directory_host, root ++ "/catalog")
    file : File <- IO.try(File, File.open(root ++ "/source/document", "r"))
    result : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 7)
    source(result, outcome, requested)

def run(mode: String, atomic: String, identity_host: String, directory_host: String,
  root: String) -> IO(Unit):
  match mode:
    case "write":
      persist(atomic, identity_host, root)
    case "read":
      read(directory_host, identity_host, root)
    case _:
      IO.die(Unit, 1, "Invalid native restart mode")

def main() -> IO(Unit):
  do IO<Unit>:
    mode : String <- IO.try(String, IO.get_env("MARKBEND_NATIVE_RECOVERY_MODE"))
    atomic : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    identity_host : String <- IO.try(String, IO.get_env("MARKBEND_IDENTITY_HOST"))
    directory_host : String <- IO.try(String, IO.get_env("MARKBEND_DIRECTORY_HOST"))
    root : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_DIRECTORY"))
    run(mode, atomic, identity_host, directory_host, root)
