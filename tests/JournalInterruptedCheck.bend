import Base
import ../src/SaveState.bend as Save
import ../src/RecoveryState.bend as Recovery
import ../src/RecoveryRecord.bend as Record
import ./RecoveryRestartCheck.bend as Restart
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check

def expected(new: Bool) -> Save.State:
  match new:
    case False{}:
      Restart.recorded()
    case True{}:
      Save.edit(Restart.recorded(), [68, 0, 255])

def stopped(result: U32 & (String & String), stop: U32) -> IO(Unit):
  match result:
    case (code, (output, error)):
      do IO<Unit>:
        Check.check(U32.is_eq(code, (70 + stop : U32)))
        IO.die(Unit, 79, "Journal updater stopped")

def update(value: Maybe<&2, String>, program: String, directory: String, +stop: U32) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Journal update encoding failed")
    case Some{text}:
      do IO<Unit>:
        result : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(program, ["--save-stop", directory ++ "/journal", U32.show(stop)], text, 4096, 10000))
        stopped(result, stop)

def recovered(result: Recovery.Decision, new: Bool) -> Bool:
  match result:
    case Recovery.Restored{state}:
      States.state_equal(state, Save.result(expected(new), 0n, False{}))
    case _:
      False{}

def source(result: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  state: Save.State, new: Bool) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        bytes : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        Check.check(recovered(Recovery.recover(state, bytes), new))
        IO.print("Interrupted journal restart check passed")

def decoded(value: Maybe<&2, Save.State>, directory: String, +new: Bool) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Interrupted journal record rejected")
    case Some{+state}:
      do IO<Unit>:
        Check.check(States.state_equal(state, expected(new)))
        file : File <- IO.try(File, File.open(directory ++ "/document", "r"))
        result : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 4096)
        source(result, state, new)

def record(result: File & Result<&1, &1, U32 & String, String>,
  directory: String, new: Bool) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        text : String <- IO.pass(String, value)
        decoded(Record.decode(text), directory, new)

def run(write: Bool, program: String, +directory: String, stop: U32, new: Bool) -> IO(Unit):
  match write:
    case True{}:
      update(Record.encode(expected(True{})), program, directory, stop)
    case False{}:
      do IO<Unit>:
        file : File <- IO.try(File, File.open(directory ++ "/journal/document", "r"))
        result : File & Result<&1, &1, U32 & String, String> <- File.read(file, 4096)
        record(result, directory, new)

def parse_stop(value: Maybe<&2, U32>) -> IO(U32):
  match value:
    case Some{stop}:
      IO.pure(U32, stop)
    case None{}:
      IO.die(U32, 1, "Invalid journal stop")

def main() -> IO(Unit):
  do IO<Unit>:
    program : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    directory : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_DIRECTORY"))
    mode : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_MODE"))
    stage : String <- IO.try(String, IO.get_env("MARKBEND_JOURNAL_STOP"))
    revision : String <- IO.try(String, IO.get_env("MARKBEND_JOURNAL_EXPECTED"))
    stop : U32 <- parse_stop(U32.read(stage))
    run(String.eq(mode, "write"), program, directory, stop, String.eq(revision, "new"))
