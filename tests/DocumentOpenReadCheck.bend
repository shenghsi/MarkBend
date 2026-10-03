import Base
import ../src/DocumentOpen.bend as Open
import ../src/SaveState.bend as Save
import ./StoredEditorCheck.bend as Editor
import ./DirectCheck.bend as Check

def next(step: Open.ReadStep, value: Result<&1, &1, U32 & String, List<&2, U32>>) -> Open.ReadStep:
  match step:
    case Open.More{state}:
      Open.advance(value, state)
    case Open.Finished{result}:
      Open.Finished{result}

def loaded(step: Open.ReadStep) -> Bool:
  match step:
    case Open.Finished{Open.Opened{session}}:
      Editor.matches(session, "中\r\n", Save.open([228,184,173,13,10]))
    case _:
      False{}

def partial(step: Open.ReadStep) -> Bool:
  match step:
    case Open.More{Open.ReadState{reversed, count}}:
      Nat.is_eq(count, 2n) && Save.bytes_equal(reversed, [184,228])
    case _:
      False{}

def failed(step: Open.ReadStep) -> Bool:
  match step:
    case Open.Finished{Open.ReadFailed{code, message}}:
      U32.is_eq(code, 7) && String.eq(message, "Read failed after prefix")
    case _:
      False{}

def oversized(step: Open.ReadStep) -> Bool:
  match step:
    case Open.Finished{Open.TooLarge{+bytes}}:
      Open.fits(8388609n, bytes) && Bool.not(Open.fits(8388608n, bytes))
    case _:
      False{}

def zeroes(fuel: Nat, reversed: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      reversed
    case 1n+remaining:
      zeroes(remaining, 0 <> reversed)

def main() -> IO(Unit):
  +first = Open.advance(Done{[228,184]}, Open.ReadState{Nil{}, 0n})
  +second = next(first, Done{[173,13]})
  +third = next(second, Done{[10]})
  do IO<Unit>:
    Check.check(partial(first))
    Check.check(loaded(next(third, Done{Nil{}})))
    Check.check(failed(next(first, Fail{(7, "Read failed after prefix")})))
    # Build an actual complete prefix, then exceed the limit in a later read.
    +full : Open.ReadStep = Open.accumulated(Open.accumulate(
      zeroes(8388607n, Nil{}), Nil{}, 0n))
    +at_limit : Open.ReadStep = next(full, Done{[0]})
    Check.check(oversized(next(at_limit, Done{[0]})))
    IO.print("Split reads, split UTF-8, late read errors, and aggregate size limit check passed")
