import Base
import ../src/SaveState.bend as Save
import ../src/RecoveryRecord.bend as Record
import ./DirectCheck.bend as Check
import ./SaveStateCheck.bend as States

def absent(value: Maybe<&2, Save.State>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def matches(value: Maybe<&2, Save.State>, expected: Save.State) -> Bool:
  match value:
    case Some{state}:
      States.state_equal(state, expected)
    case _:
      False{}

def truncated(fuel: Nat, +text: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      +length = p
      do IO<Unit>:
        Check.check(absent(Record.decode(String.take(text, length))))
        Check.check(absent(Record.decode(String.take(text, length) ++ "x" ++
          String.drop(text, 1n+length))))
        truncated(length, text)

def encoded(value: Maybe<&2, String>, state: Save.State) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Valid recovery state did not encode")
    case Some{+text}:
      do IO<Unit>:
        Check.check(matches(Record.decode(text), state))
        Check.check(absent(Record.decode(text ++ "x")))
        truncated(String.length(text), text)

def roundtrip(+state: Save.State) -> IO(Unit):
  encoded(Record.encode(state), state)

def invalid(value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def all_bytes(count: Nat) -> List<&2, U32>:
  match count:
    case 0n:
      Nil{}
    case 1n+ +p:
      Con{U32.from_nat(p), all_bytes(p)}

def payload_record(current: String) -> String:
  Record.sealed(Record.prefix("MBR2", "0", current, "", "-", ""))

def main() -> IO(Unit):
  do IO<Unit>:
    Check.check(String.eq(Record.bytes_text([0, 15, 16, 127, 128, 255]), "000f107f80ff"))
    roundtrip(Save.open(Nil{}))
    roundtrip(Save.open([0, 13, 10, 255, 195, 40]))
    roundtrip(Save.open(all_bytes(256n)))
    roundtrip(Save.edit(Save.request(Save.edit(Save.open([65]), [66, 0, 255])), [67]))
    roundtrip(Save.State{[255], Nil{}, U32.to_nat(4294967295),
      Some{Save.Ticket{U32.to_nat(4294967294), [0]}}})
    Check.check(invalid(Record.encode(Save.open([256]))))
    Check.check(invalid(Record.encode(Save.State{[65], [66], 1n, Some{Save.Ticket{1n, [67]}}})))
    Check.check(absent(Record.decode("MBR1\n0\n\n\n-\n\n0\nEND")))
    Check.check(matches(Record.decode(Record.sealed(Record.prefix("MBR1", "0",
      "0,255,13,10,", "0,255,13,10,", "-", ""))), Save.open([0, 255, 13, 10])))
    Check.check(absent(Record.decode(payload_record("0"))))
    Check.check(absent(Record.decode(payload_record("gg"))))
    Check.check(absent(Record.decode(payload_record("g0"))))
    Check.check(absent(Record.decode(payload_record("0g"))))
    Check.check(absent(Record.decode(payload_record("FF"))))
    Check.check(absent(Record.decode(payload_record("00,"))))
    IO.print("Recovery record batch passed")
