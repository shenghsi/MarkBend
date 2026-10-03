import Base
import ../src/SaveState.bend as Save
import ../src/RecoveryState.bend as Recovery
import ./DirectCheck.bend as Check
import ./SaveHostCheck.bend as Host

def snapshot() -> List<&2, U32>:
  [66, 13, 10, 240, 159, 152, 128]

def pending_matches(value: Maybe<&2, Save.Ticket>, uncertain: Bool) -> Bool:
  match value uncertain:
    case None{} False{}:
      True{}
    case Some{Save.Ticket{id, bytes}} True{}:
      Nat.is_eq(id, 0n) && Save.bytes_equal(bytes, snapshot())
    case _ _:
      False{}

def state_matches(state: Save.State, uncertain: Bool) -> Bool:
  match state:
    case Save.State{current, saved, next, pending}:
      Save.bytes_equal(current, [67]) && Save.bytes_equal(saved, [65]) &&
        Nat.is_eq(next, 1n) && pending_matches(pending, uncertain)

def reconciled(uncertain: Bool, state: Save.State) -> Bool:
  match uncertain:
    case True{}:
      Host.done_matches(state)
    case False{}:
      state_matches(state, False{})

def recovered(result: Recovery.Decision, uncertain: Bool) -> Bool:
  match result:
    case Recovery.Restored{state}:
      reconciled(uncertain, state)
    case _:
      False{}

def read_matches(+bytes: List<&2, U32>, expected: List<&2, U32>,
  +state: Save.State, +uncertain: Bool) -> IO(Unit):
  do IO<Unit>:
    Check.check(Save.bytes_equal(bytes, expected))
    Check.check(recovered(Recovery.recover(state, bytes), uncertain))
    Check.check(reconciled(uncertain, Save.reconcile(state, 0n, bytes, True{})))

def disk(result: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  expected: List<&2, U32>, state: Save.State, uncertain: Bool) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        bytes : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        read_matches(bytes, expected, state, uncertain)

def synced(result: U32 & (String & String)) -> IO(Unit):
  match result:
    case (code, (output, error)):
      Check.check(U32.is_eq(code, 0))

def outcome(uncertain: Bool) -> Save.Outcome:
  match uncertain:
    case True{}:
      Save.ReplacementUncertain{}
    case False{}:
      Save.OldKept{}

def expected(uncertain: Bool) -> List<&2, U32>:
  match uncertain:
    case True{}:
      snapshot()
    case False{}:
      [65]

def finished(result: U32 & (String & String), path: String, program: String, directory: String,
  state: Save.State, +stop: U32) -> IO(Unit):
  match result:
    case (code, (output, error)):
      +uncertain = U32.is_eq(stop, 4)
      +done = Save.complete(state, 0n, outcome(uncertain))
      do IO<Unit>:
        Check.check(U32.is_eq(code, (70 + stop : U32)))
        Check.check(state_matches(done, uncertain))
        sync : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(program, ["--sync", directory], "", 4096, 10000))
        synced(sync)
        file : File <- IO.try(File, File.open(path, "r"))
        read : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 4096)
        disk(read, expected(uncertain), done, uncertain)

def one(+program: String, +directory: String, +stop: U32) -> IO(Unit):
  +path = directory ++ "/document"
  state = Save.edit(Save.request(Save.edit(Save.open([65]), snapshot())), [67])
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    written : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(file, [65])
    Host.written(written)
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(program, ["--save-stop", directory, U32.show(stop)], "B\r\n😀", 4096, 10000))
    finished(result, path, program, directory, state, stop)

def run(fuel: Nat, +program: String, +directory: String, +stop: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("Bend interrupted save host check passed")
    case 1n+p:
      do IO<Unit>:
        one(program, directory ++ "/" ++ U32.show(stop), stop)
        run(p, program, directory, (stop + 1 : U32))

def main() -> IO(Unit):
  do IO<Unit>:
    program : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    directory : String <- IO.try(String, IO.get_env("MARKBEND_SAVE_DIRECTORY"))
    run(5n, program, directory, 0)
