import Base
import ../src/ByteBuffer.bend as Bytes
import ../src/Utf8.bend as Utf8
import ../src/SaveState.bend as Save
import ./ByteBufferCheck.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./DocumentBench.bend as Markdown
import ./DirectCheck.bend as Check

def sample(+base: Bytes.Buffer, +pending: Bytes.Buffer, +original: List<&2, U32>,
  insert: Bytes.Buffer, number: Nat) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    +result : Bytes.Buffer = Fixture.edits(1000n, base, insert)
    stop : Nat <- IO.now()
    Check.check(Bytes.valid(result))
    Check.check(Nat.is_eq(Bytes.length(result), 1049576n))
    Check.check(Save.bytes_equal(Fixture.prefix(Bytes.materialize(result), 1000n), original))
    Check.check(Save.bytes_equal(Bytes.materialize(base), original))
    Check.check(Save.bytes_equal(Fixture.prefix(Bytes.materialize(pending), 1n), original))
    IO.print("byte_buffer sample=" ++ Nat.show(number) ++
      " edits=1000 elapsed_ms=" ++ Nat.show(Nat.sub(stop, start)))

def repeat(fuel: Nat, +base: Bytes.Buffer, +pending: Bytes.Buffer,
  +original: List<&2, U32>, +insert: Bytes.Buffer, +number: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("One-MiB persistent byte buffer edit benchmark passed")
    case 1n+rest:
      do IO<Unit>:
        sample(base, pending, original, insert, number)
        repeat(rest, base, pending, original, insert, 1n+number)

def main() -> IO(Unit):
  +original = Encode.bytes(Utf8.encode(Markdown.sample(1048576n)))
  +base = Fixture.buffer(Bytes.from_bytes(original))
  +insert = Fixture.buffer(Bytes.from_bytes([88]))
  +pending = Bytes.replace(base, 0n, 0n, insert)
  repeat(20n, base, pending, original, insert, 1n)
