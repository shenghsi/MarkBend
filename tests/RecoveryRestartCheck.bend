import Base
import ../src/SaveState.bend as Save
import ../src/RecoveryState.bend as Recovery
import ../src/RecoveryRecord.bend as Record
import ./DirectCheck.bend as Check
import ./SaveStateCheck.bend as States
import ./SaveHostCheck.bend as Host

def old_bytes() -> List<&2, U32>:
  [65, 0, 255]

def pending_bytes() -> List<&2, U32>:
  [66, 13, 10, 240, 159, 152, 128]

def recorded() -> Save.State:
  Save.edit(Save.request(Save.edit(Save.open(old_bytes()), pending_bytes())), [67, 0, 255])

def source_bytes(new: Bool) -> List<&2, U32>:
  match new:
    case False{}:
      old_bytes()
    case True{}:
      pending_bytes()

def process_ok(result: U32 & (String & String)) -> IO(Unit):
  match result:
    case (code, (output, error)):
      Check.check(U32.is_eq(code, 0))

def write_bytes(path: String, bytes: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(file, bytes)
    Host.written(result)

def write_record(value: Maybe<&2, String>, +program: String, +directory: String,
  new: Bool) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Recovery record encoding failed")
    case Some{text}:
      do IO<Unit>:
        write_bytes(directory ++ "/document", source_bytes(new))
        synced : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(program, ["--sync", directory], "", 4096, 10000))
        process_ok(synced)
        write_bytes(directory ++ "/journal/document", [0])
        saved : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(program, ["--save", directory ++ "/journal"], text, 4096, 10000))
        process_ok(saved)
        IO.die(Unit, 79, "Recovery writer stopped after durable record")

def recovered(result: Recovery.Decision, new: Bool) -> Bool:
  match result:
    case Recovery.Restored{state}:
      States.state_equal(state, Save.State{[67, 0, 255], source_bytes(new), 1n, None{}})
    case _:
      False{}

def read_source(result: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  state: Save.State, new: Bool) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        bytes : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        Check.check(recovered(Recovery.recover(state, bytes), new))
        IO.print("Recovery restart check passed")

def decoded(value: Maybe<&2, Save.State>, directory: String, new: Bool) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Recovery record rejected")
    case Some{+state}:
      do IO<Unit>:
        Check.check(States.state_equal(state, recorded()))
        file : File <- IO.try(File, File.open(directory ++ "/document", "r"))
        result : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 4096)
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
        result : File & Result<&1, &1, U32 & String, String> <- File.read(file, 4096)
        read_record(result, directory, new)

def main() -> IO(Unit):
  do IO<Unit>:
    program : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    directory : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_DIRECTORY"))
    mode : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_MODE"))
    disk : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_DISK"))
    run(String.eq(mode, "write"), program, directory, String.eq(disk, "new"))
