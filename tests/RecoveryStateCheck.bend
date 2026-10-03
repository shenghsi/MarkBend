import Base
import ../src/SaveState.bend as Save
import ../src/RecoveryState.bend as Recovery
import ./DirectCheck.bend as Check
import ./SaveStateCheck.bend as StateCheck

def restored(result: Recovery.Decision, expected: Save.State) -> Bool:
  match result:
    case Recovery.Restored{state}:
      StateCheck.state_equal(state, expected)
    case _:
      False{}

def conflict(result: Recovery.Decision, recorded: Save.State, disk: List<&2, U32>) -> Bool:
  match result:
    case Recovery.Conflict{state, bytes}:
      StateCheck.state_equal(state, recorded) && Save.bytes_equal(bytes, disk)
    case _:
      False{}

def main() -> IO(Unit):
  +recorded = Save.edit(Save.request(Save.edit(Save.open([65, 0, 255]), [66, 0, 255])), [67, 0, 255])
  +plain = Save.edit(Save.open([65]), [67])
  do IO<Unit>:
    Check.check(restored(Recovery.recover(recorded, [65, 0, 255]),
      Save.State{[67, 0, 255], [65, 0, 255], 1n, None{}}))
    Check.check(restored(Recovery.recover(recorded, [66, 0, 255]),
      Save.State{[67, 0, 255], [66, 0, 255], 1n, None{}}))
    Check.check(conflict(Recovery.recover(recorded, [88, 0, 255]), recorded, [88, 0, 255]))
    Check.check(restored(Recovery.recover(plain, [65]), Save.State{[67], [65], 0n, None{}}))
    Check.check(conflict(Recovery.recover(plain, [88]), plain, [88]))
    Check.check(restored(Recovery.recover(Save.open(Nil{}), Nil{}), Save.open(Nil{})))
    IO.print("Recovery state batch passed")
