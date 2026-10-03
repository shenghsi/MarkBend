import Base
import ../src/ByteBuffer.bend as Bytes
import ../src/BlockIndex.bend as Index
import ../src/SaveState.bend as Save
import ./RecoveryRecordBench.bend as Fixture
import ./DirectCheck.bend as Check

def buffer(value: Maybe<&2, Bytes.Buffer>) -> Bytes.Buffer:
  match value:
    case Some{result}:
      result
    case None{}:
      Bytes.Buffer{Index.Empty{}}

def rejected(value: Maybe<&2, Bytes.Buffer>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def cut(bytes: List<&2, U32>, count: Nat, reversed: List<&2, U32>) ->
  List<&2, U32> & List<&2, U32>:
  match bytes count:
    case rest 0n:
      (reversed, rest)
    case Nil{} _:
      (reversed, Nil{})
    case byte <> rest 1n+left:
      cut(rest, left, byte <> reversed)

def restore(reversed: List<&2, U32>, suffix: List<&2, U32>) -> List<&2, U32>:
  match reversed:
    case Nil{}:
      suffix
    case byte <> rest:
      restore(rest, byte <> suffix)

def splice_cut(value: List<&2, U32> & List<&2, U32>, removed: Nat,
  insert: List<&2, U32>) -> List<&2, U32>:
  match value:
    case (reversed, suffix):
      restore(reversed, List.append(&2, U32, insert, List.drop(&2, U32, suffix, removed)))

def splice(bytes: List<&2, U32>, +start: Nat, +end: Nat,
  insert: List<&2, U32>) -> List<&2, U32>:
  splice_cut(cut(bytes, Nat.min(start, end), Nil{}),
    Nat.sub(Nat.max(start, end), Nat.min(start, end)), insert)

def ranges(ends: List<&2, Nat>, +source: Bytes.Buffer, +original: List<&2, U32>,
  +start: Nat, ok: Bool) -> Bool:
  match ends:
    case Nil{}:
      ok
    case +end <> rest:
      +changed = Bytes.replace(source, start, end, buffer(Bytes.from_bytes([88, 0, 255])))
      ranges(rest, source, original, start, ok && Bytes.valid(changed) &&
        Save.bytes_equal(Bytes.materialize(changed), splice(original, start, end, [88, 0, 255])))

def starts(positions: List<&2, Nat>, +ends: List<&2, Nat>, +source: Bytes.Buffer,
  +original: List<&2, U32>, ok: Bool) -> Bool:
  match positions:
    case Nil{}:
      ok
    case start <> rest:
      starts(rest, ends, source, original, ok && ranges(ends, source, original, start, True{}))

def edits(fuel: Nat, source: Bytes.Buffer, +insert: Bytes.Buffer) -> Bytes.Buffer:
  match fuel:
    case 0n:
      source
    case 1n+rest:
      edits(rest, Bytes.replace(source, 0n, 0n, insert), insert)

def prefix(bytes: List<&2, U32>, fuel: Nat) -> List<&2, U32>:
  match bytes fuel:
    case rest 0n:
      rest
    case 88 <> rest 1n+left:
      prefix(rest, left)
    case _ _:
      [256]

def main() -> IO(Unit):
  +small = Fixture.fixture(256n, Nil{})
  +source = buffer(Bytes.from_bytes(small))
  +positions : List<&2, Nat> = [0n, 1n, 511n, 512n, 513n, 1023n, 1024n, 2048n]
  +original = Fixture.fixture(262144n, Nil{})
  +large = buffer(Bytes.from_bytes(original))
  +large_positions : List<&2, Nat> = [0n, 511n, 524288n, 1048576n, 2097152n]
  +insert = buffer(Bytes.from_bytes([88]))
  +pending = Bytes.replace(large, 0n, 0n, insert)
  +changed = edits(20n, large, insert)
  do IO<Unit>:
    Check.check(Bytes.equal(source, buffer(Bytes.from_bytes(small))))
    Check.check(Bool.not(Bytes.equal(large, pending)))
    Check.check(Bool.not(Bytes.equal(large, Bytes.replace(large, 0n, 1n, insert))))
    Check.check(Bool.not(Bytes.equal(large, Bytes.replace(large, 524288n, 524289n, insert))))
    Check.check(Bool.not(Bytes.equal(large, Bytes.replace(large, 1048575n, 1048576n, insert))))
    Check.check(Bytes.equal(large, Bytes.replace(changed, 0n, 20n, buffer(Bytes.from_bytes(Nil{})))))
    Check.check(rejected(Bytes.from_bytes([256])))
    Check.check(rejected(Bytes.from_bytes([0, 4294967295])))
    Check.check(Bytes.valid(buffer(Bytes.from_bytes(Nil{}))))
    Check.check(starts(positions, positions, source, small, True{}))
    Check.check(starts(large_positions, large_positions, large, original, True{}))
    Check.check(Save.bytes_equal(Bytes.materialize(source), small))
    Check.check(Bytes.valid(large) && Bytes.valid(pending) && Bytes.valid(changed))
    Check.check(Nat.is_eq(Bytes.length(large), 1048576n))
    Check.check(Nat.is_eq(Bytes.length(pending), 1048577n))
    Check.check(Nat.is_eq(Bytes.length(changed), 1048596n))
    Check.check(Save.bytes_equal(Bytes.materialize(large), original))
    Check.check(Save.bytes_equal(prefix(Bytes.materialize(pending), 1n), original))
    Check.check(Save.bytes_equal(prefix(Bytes.materialize(changed), 20n), original))
    Check.check(Bytes.valid(Bytes.replace(changed, 0n, 20n, buffer(Bytes.from_bytes(Nil{})))))
    Check.check(Save.bytes_equal(Bytes.materialize(
      Bytes.replace(changed, 0n, 20n, buffer(Bytes.from_bytes(Nil{})))), original))
    IO.print("Persistent byte buffer ranges, snapshots, and one-MiB edits check passed")
