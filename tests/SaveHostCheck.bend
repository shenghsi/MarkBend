import Base
import ../src/SaveState.bend as Save
import ./DirectCheck.bend as Check

def written(result: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        IO.pass(Unit, value)

def disk(result: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        bytes : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        Check.check(Save.bytes_equal(bytes, [66, 13, 10, 240, 159, 152, 128]))

def done_matches(state: Save.State) -> Bool:
  match state:
    case Save.State{current, saved, next, None{}}:
      Save.bytes_equal(current, [67]) &&
        Save.bytes_equal(saved, [66, 13, 10, 240, 159, 152, 128]) && Nat.is_eq(next, 1n)
    case _:
      False{}

def finished(result: U32 & (String & String), +path: String,
  state: Save.State) -> IO(Unit):
  match result:
    case (code, (output, error)):
      +done = Save.complete(state, 0n, Save.Confirmed{})
      do IO<Unit>:
        Check.check(U32.is_eq(code, 0))
        Check.check(done_matches(done))
        Check.check(Save.dirty(done))
        Check.check(Bool.not(Save.dirty(Save.edit(done,
          [66, 13, 10, 240, 159, 152, 128]))))
        file : File <- IO.try(File, File.open(path, "r"))
        read : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 4096)
        disk(read)
        IO.print("Bend atomic save host check passed")

def run(program: String, +directory: String) -> IO(Unit):
  +path = directory ++ "/document"
  snapshot = Save.request(Save.edit(Save.open([65]), [66, 13, 10, 240, 159, 152, 128]))
  edited = Save.edit(snapshot, [67])
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(file, [65])
    written(result)
    saved : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(program, ["--save", directory], "B\r\n😀", 4096, 10000))
    finished(saved, path, edited)

def main() -> IO(Unit):
  do IO<Unit>:
    program : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    directory : String <- IO.try(String, IO.get_env("MARKBEND_SAVE_DIRECTORY"))
    run(program, directory)
