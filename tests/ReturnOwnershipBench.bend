import Base
import ./ReturnCommandBench.bend as Core
import ./ReturnCommandCheck.bend as Result
import ./StoredEditorCheck.bend as Storage
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check
import ../src/StoredEditor.bend as Stored
import ../src/ReturnCommand.bend as Return
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8

# This control carries the Undo result forward. It does not carry the first
# session through all samples. Verification and Undo are outside the clock.
def cycles(fuel: Nat, +number: Nat, +session: Stored.Session,
  +source: String, +expected: String, +initial: Flat.State, +saved: Flat.State) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("Undo baseline Return samples passed")
    case 1n+rest:
      do IO<Unit>:
        Check.check(Core.preflight(session, 65538n, 65538n))
        +start : Nat <- IO.now()
        +next : Stored.Session <- Storage.accepted(Return.command(session, 65538n, 65538n))
        Check.check(Core.forced(next, 65541n, 65541n))
        +stop : Nat <- IO.now()
        Check.check(Result.verified(next, expected, 65541n, 65541n, saved))
        +undone : Stored.Session = Stored.undo(next)
        Check.check(Result.verified(undone, source, 65538n, 65538n, initial))
        Check.check(Result.verified(Stored.redo(undone), expected, 65541n, 65541n, saved))
        IO.print("undo_return sample=" ++ Nat.show(number) ++
          " elapsed_ms=" ++ Nat.show(Nat.sub(stop, start)))
        cycles(rest, 1n+number, undone, source, expected, initial, saved)

def control(original: Bool, session: Stored.Session, source: String,
  expected: String, initial: Flat.State, saved: Flat.State) -> IO(Unit):
  match original:
    case True{}:
      Core.ready(session, source, expected, 65538n, initial, saved)
    case False{}:
      cycles(20n, 1n, Stored.select(session, 65538n, 65538n), source, expected, initial, saved)

def run(original: Bool) -> IO(Unit):
  +source = "- " ++ Result.repeated(65536n, "")
  +expected = Core.appended(source, "\n- ")
  +initial = Flat.open(Encode.bytes(Utf8.encode(source)))
  +saved = Flat.edit(initial, Encode.bytes(Utf8.encode(expected)))
  do IO<Unit>:
    session : Stored.Session <- Storage.loaded(Stored.load(initial))
    control(original, session, source, expected, initial, saved)

def choose(args: List<String>) -> IO(Unit):
  match args:
    case program <> "original" <> Nil{}:
      run(True{})
    case program <> "undo" <> Nil{}:
      run(False{})
    case _:
      IO.die(Unit, 1, "Use original or undo")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    choose(args)
