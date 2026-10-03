import Base
import ../src/TextStorage.bend as Storage
import ../src/ByteBuffer.bend as Bytes
import ../src/TextByteMap.bend as Mapping
import ../src/BlockIndex.bend as Index
import ../src/Utf8.bend as Utf8
import ../src/SaveState.bend as Save
import ./TextByteMapCheck.bend as Reference
import ./RecoveryEditorCheck.bend as Encode
import ./ByteBufferCheck.bend as Buffer
import ./Utf8Check.bend as Text
import ./DirectCheck.bend as Check

def snapshot(value: Maybe<&2, Storage.Snapshot>) -> Storage.Snapshot:
  match value:
    case Some{result}:
      result
    case None{}:
      Storage.Snapshot{Bytes.Buffer{Index.Leaf{Bytes.Chunk{[256]}, 1n}},
        Mapping.Mapping{Index.Empty{}, Index.Empty{}}}

def accepted(value: Storage.EditResult) -> Storage.Snapshot:
  match value:
    case Storage.Accepted{result}:
      result
    case Storage.Rejected{result}:
      snapshot(None{})

def rejected(value: Maybe<&2, Storage.Snapshot>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def matches(+value: Storage.Snapshot, +expected: String) -> Bool:
  match value:
    case Storage.Snapshot{bytes, map}:
      Storage.valid(value) &&
        Text.text_equal(Reference.map_source(map), expected, True{}) &&
        Save.bytes_equal(Storage.materialize(value), Encode.bytes(Utf8.encode(expected)))

def ends(positions: List<&2, Nat>, +original: Storage.Snapshot, +text: String,
  +start: Nat, +insert: String, ok: Bool) -> Bool:
  match positions:
    case Nil{}:
      ok
    case +end <> rest:
      ends(rest, original, text, start, insert, ok &&
        matches(accepted(Storage.replace(original, start, end, insert)),
          Reference.replace_text(text, start, end, insert)))

def starts(positions: List<&2, Nat>, +all: List<&2, Nat>, +original: Storage.Snapshot,
  +text: String, +insert: String, ok: Bool) -> Bool:
  match positions:
    case Nil{}:
      ok
    case start <> rest:
      starts(rest, all, original, text, insert, ok &&
        ends(all, original, text, start, insert, True{}))

def edits(fuel: Nat, original: Storage.Snapshot) -> Storage.Snapshot:
  match fuel:
    case 0n:
      original
    case 1n+rest:
      edits(rest, accepted(Storage.replace(original, 0n, 0n, "X")))

def failed(value: Storage.EditResult, expected: String) -> Bool:
  match value:
    case Storage.Rejected{old}:
      matches(old, expected)
    case _:
      False{}

def large() -> IO(Unit):
  +text = Reference.repeat_text(16384n, String.repeat("x", 64n), "")
  +old = snapshot(Storage.from_text(text))
  +pending = accepted(Storage.replace(old, 0n, 0n, "X"))
  +current = edits(20n, old)
  +middle = accepted(Storage.replace(old, 524289n, 524293n, "中😀"))
  do IO<Unit>:
    Check.check(matches(old, text))
    Check.check(matches(pending, Reference.append_text("X", text)))
    Check.check(matches(current, Reference.append_text(String.repeat("X", 20n), text)))
    Check.check(Storage.valid(middle))
    Check.check(Save.bytes_equal(Storage.materialize(middle), Buffer.splice(
      Storage.materialize(old), 524289n, 524293n, [228, 184, 173, 240, 159, 152, 128])))
    Check.check(matches(accepted(Storage.replace(current, 0n, 20n, "")), text))
    Check.check(matches(old, text))

def main() -> IO(Unit):
  +text = String.repeat("A中😀e\u{301}\0\r\n\u{feff}", 64n)
  +old = snapshot(Storage.from_bytes(Encode.bytes(Utf8.encode(text))))
  +positions : List<&2, Nat> = [0n, 1n, 4n, 127n, 128n, 129n, 255n, 256n, 575n, 576n, 999n]
  +insert : String = "新😀\r\n"
  +paste = Reference.repeat_text(1024n, "中文😀\r\n", "")
  do IO<Unit>:
    Check.check(rejected(Storage.from_bytes([255, 0, 13, 10])))
    Check.check(rejected(Storage.from_bytes([226, 130])))
    Check.check(matches(snapshot(Storage.from_bytes(Nil{})), ""))
    Check.check(starts(positions, positions, old, text, insert, True{}))
    Check.check(starts(positions, positions, old, text, "", True{}))
    Check.check(matches(accepted(Storage.replace(old, 4n, 4n, paste)),
      Reference.replace_text(text, 4n, 4n, paste)))
    Check.check(matches(old, text))
    Check.check(failed(Storage.edited(old, None{}, Some{Nil{}}, Some{0n}, Some{0n}), text))
    large()
    IO.print("Persistent text storage scalar edits, exact bytes, and snapshots check passed")
