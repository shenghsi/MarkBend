import Base
import ../src/SaveState.bend as Save
import ../src/RecoveryState.bend as Recovery
import ../src/RecoveryRecord.bend as Record
import ./RecoveryLargeRestartCheck.bend as Large
import ./RecoveryRestartCheck.bend as Restart
import ./JournalInterruptedCheck.bend as Journal
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check

def conflict(result: Recovery.Decision, head: U32) -> Bool:
  match result:
    case Recovery.Conflict{recorded, disk}:
      States.state_equal(recorded, Large.recorded()) && Save.bytes_equal(disk, Large.bytes(head))
    case _:
      False{}

def source(result: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  state: Save.State, head: U32) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        bytes : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        Check.check(conflict(Recovery.recover(state, bytes), head))
        IO.print("One-MiB recovery conflict restart check passed")

def decoded(value: Maybe<&2, Save.State>, directory: String, head: U32) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Conflict recovery record rejected")
    case Some{+state}:
      do IO<Unit>:
        Check.check(States.state_equal(state, Large.recorded()))
        file : File <- IO.try(File, File.open(directory ++ "/document", "r"))
        result : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 1048577)
        source(result, state, head)

def record(result: File & Result<&1, &1, U32 & String, String>,
  directory: String, head: U32) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        text : String <- IO.pass(String, value)
        decoded(Record.decode(text), directory, head)

def run(write: Bool, external: Bool, +program: String, +directory: String, head: U32) -> IO(Unit):
  match write external:
    case True{} _:
      Large.run(True{}, program, directory, False{})
    case False{} True{}:
      do IO<Unit>:
        Restart.write_bytes(directory ++ "/document", Large.bytes(head))
        synced : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(program, ["--sync", directory], "", 4096, 30000))
        Restart.process_ok(synced)
    case False{} False{}:
      do IO<Unit>:
        file : File <- IO.try(File, File.open(directory ++ "/journal/document", "r"))
        result : File & Result<&1, &1, U32 & String, String> <- File.read(file, 8388609)
        record(result, directory, head)

def run_mode(+mode: String, program: String, directory: String, head: U32) -> IO(Unit):
  run(String.eq(mode, "write"), String.eq(mode, "external"), program, directory, head)

def main() -> IO(Unit):
  do IO<Unit>:
    program : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    directory : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_DIRECTORY"))
    mode : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_MODE"))
    external : String <- IO.try(String, IO.get_env("MARKBEND_EXTERNAL_HEAD"))
    head : U32 <- Journal.parse_stop(U32.read(external))
    run_mode(mode, program, directory, head)
