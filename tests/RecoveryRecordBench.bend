import Base
import ../src/SaveState.bend as Save
import ../src/RecoveryRecord.bend as Record
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check

def fixture(count: Nat, bytes: List<&2, U32>) -> List<&2, U32>:
  match count:
    case 0n:
      bytes
    case 1n+p:
      fixture(p, 0 <> 255 <> 13 <> 10 <> bytes)

def decoded(value: Maybe<&2, Save.State>, expected: Save.State) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Large recovery record rejected")
    case Some{state}:
      do IO<Unit>:
        Check.check(States.state_equal(state, expected))
        IO.print("One-MiB recovery record check passed")

def encoded(value: Maybe<&2, String>, state: Save.State) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Large recovery record did not encode")
    case Some{+text}:
      do IO<Unit>:
        IO.print("recovery_record_bytes=" ++ Nat.show(String.length(text)))
        decoded(Record.decode(text), state)

def main() -> IO(Unit):
  +state = Save.open(fixture(262144n, Nil{}))
  encoded(Record.encode(state), state)
