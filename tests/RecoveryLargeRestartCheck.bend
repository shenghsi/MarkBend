import Base
import ../src/SaveState.bend as Save
import ../src/RecoveryState.bend as Recovery
import ../src/RecoveryRecord.bend as Record
import ./RecoveryRecordBench.bend as Bench
import ./RecoveryRestartCheck.bend as Restart
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check

def bytes(head: U32) -> List<&2, U32>:
  head <> 0 <> 255 <> 10 <> Bench.fixture(262143n, Nil{})

def recorded() -> Save.State:
  Save.State{bytes(67), bytes(65), 1n, Some{Save.Ticket{0n, bytes(66)}}}

def disk_bytes(new: Bool) -> List<&2, U32>:
  match new:
    case True{}:
      bytes(66)
    case False{}:
      bytes(65)

def write_record(value: Maybe<&2, String>, +program: String, +directory: String,
  new: Bool) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Large recovery record encoding failed")
    case Some{+text}:
      do IO<Unit>:
        Check.check(Nat.is_gt(String.length(text), 6291456n))
        Restart.write_bytes(directory ++ "/document", disk_bytes(new))
        synced : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(program, ["--sync", directory], "", 4096, 30000))
        Restart.process_ok(synced)
        Restart.write_bytes(directory ++ "/journal/document", [0])
        saved : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(program, ["--save", directory ++ "/journal"], text, 4096, 30000))
        Restart.process_ok(saved)
        IO.die(Unit, 79, "Large recovery writer stopped after durable record")

def restored(result: Recovery.Decision, new: Bool) -> Bool:
  match result:
    case Recovery.Restored{state}:
      States.state_equal(state, Save.State{bytes(67), disk_bytes(new), 1n, None{}})
    case _:
      False{}

def read_source(result: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  state: Save.State, new: Bool) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        actual : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        Check.check(restored(Recovery.recover(state, actual), new))
        IO.print("One-MiB recovery restart check passed")

def decoded(value: Maybe<&2, Save.State>, directory: String, new: Bool) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Large recovery record rejected")
    case Some{+state}:
      do IO<Unit>:
        Check.check(States.state_equal(state, recorded()))
        file : File <- IO.try(File, File.open(directory ++ "/document", "r"))
        result : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 1048577)
        read_source(result, state, new)

def read_record(result: File & Result<&1, &1, U32 & String, String>,
  directory: String, new: Bool) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        text : String <- IO.pass(String, value)
        decoded(Record.decode(text), directory, new)

def run(write: Bool, program: String, +directory: String, new: Bool) -> IO(Unit):
  match write:
    case True{}:
      write_record(Record.encode(recorded()), program, directory, new)
    case False{}:
      do IO<Unit>:
        file : File <- IO.try(File, File.open(directory ++ "/journal/document", "r"))
        result : File & Result<&1, &1, U32 & String, String> <- File.read(file, 8388609)
        read_record(result, directory, new)

def main() -> IO(Unit):
  do IO<Unit>:
    program : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    directory : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_DIRECTORY"))
    mode : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_MODE"))
    disk : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_DISK"))
    run(String.eq(mode, "write"), program, directory, String.eq(disk, "new"))
