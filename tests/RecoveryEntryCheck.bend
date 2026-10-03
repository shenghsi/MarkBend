import Base
import ../src/RecoveryEntry.bend as Entry
import ../src/RecoveryState.bend as Recovery
import ../src/SaveState.bend as Save
import ../src/RecoveryRecord.bend as Record
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check

def wrong(value: Entry.Decision, expected: Entry.Entry, actual: List<&2, U32>) -> Bool:
  match value expected:
    case Entry.WrongDocument{Entry.Entry{key, state}, disk} Entry.Entry{ek, es}:
      Save.bytes_equal(key, ek) && States.state_equal(state, es) && Save.bytes_equal(disk, actual)
    case _ _:
      False{}

def restored(value: Entry.Decision, expected: Save.State) -> Bool:
  match value:
    case Entry.ForDocument{Recovery.Restored{state}}:
      States.state_equal(state, expected)
    case _:
      False{}

def absent(value: Maybe<&2, Entry.Entry>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def invalid(value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def conflicts(value: Entry.Decision, state: Save.State) -> Bool:
  match value:
    case Entry.ForDocument{Recovery.Conflict{recorded, disk}}:
      States.state_equal(recorded, state) && Save.bytes_equal(disk, [70])
    case _:
      False{}

def truncated(fuel: Nat, +text: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+ +p:
      do IO<Unit>:
        Check.check(absent(Entry.decode(String.take(text, p))))
        truncated(p, text)

def decoded(value: Maybe<&2, Entry.Entry>, +expected: Entry.Entry) -> IO(Unit):
  match value expected:
    case Some{+entry} Entry.Entry{+key, +state}:
      do IO<Unit>:
        Check.check(wrong(Entry.recover([98], entry, Nil{}), Entry.Entry{key, state}, Nil{}))
        Check.check(wrong(Entry.recover(Nil{}, entry, Nil{}), Entry.Entry{key, state}, Nil{}))
        Check.check(restored(Entry.recover(key, entry, Nil{}), state))
        Check.check(conflicts(Entry.recover(key, entry, [70]), state))
    case _ _:
      IO.die(Unit, 1, "Bound recovery entry rejected")

def encoded(value: Maybe<&2, String>, expected: Entry.Entry) -> IO(Unit):
  match value:
    case Some{+text}:
      do IO<Unit>:
        decoded(Entry.decode(text), expected)
        Check.check(absent(Entry.decode(text ++ "x")))
        Check.check(absent(Entry.decode(String.take(text, 5n) ++ "62" ++ String.drop(text, 7n))))
        Check.check(absent(Entry.decode(String.take(text, Nat.sub(String.length(text), 1n)))))
        truncated(String.length(text), text)
    case None{}:
      IO.die(Unit, 1, "Bound recovery entry did not encode")

def main() -> IO(Unit):
  +state = Save.edit(Save.open(Nil{}), [65, 0, 255])
  +entry = {Entry.Entry{[97, 0, 255, 10], state} : Entry.Entry}
  do IO<Unit>:
    encoded(Entry.encode(entry), entry)
    Check.check(invalid(Entry.encode(Entry.Entry{Nil{}, state})))
    Check.check(invalid(Entry.encode(Entry.Entry{[256], state})))
    Check.check(absent(Entry.decode(Record.encode_raw(state))))
    Check.check(absent(Entry.decode(Record.sealed(Entry.prefix("", Record.encode_raw(state))))))
    Check.check(absent(Entry.decode(Record.sealed(Entry.prefix("0g", Record.encode_raw(state))))))
    Check.check(absent(Entry.decode(Record.sealed(Entry.prefix("61", "MBR2\n0\n\n\n-\n\n0\nEND")))))
    IO.print("Recovery document identity check passed")
