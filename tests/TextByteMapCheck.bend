import Base
import ../src/TextByteMap.bend as Mapping
import ../src/BlockIndex.bend as Index
import ../src/ByteBuffer.bend as Bytes
import ../src/Utf8.bend as Utf8
import ../src/SaveState.bend as Save
import ./Utf8Check.bend as Text
import ./ByteBufferCheck.bend as Buffer
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def mapping(value: Maybe<&2, Mapping.Mapping>) -> Mapping.Mapping:
  match value:
    case Some{map}:
      map
    case None{}:
      Mapping.Mapping{Index.Empty{}, Index.Empty{}}

def equal(value: Maybe<&2, Nat>, expected: Nat) -> Bool:
  match value:
    case Some{actual}:
      Nat.is_eq(actual, expected)
    case None{}:
      False{}

def take_text(text: String, count: Nat, reversed: String) -> String:
  match text count:
    case _ 0n:
      String.reverse(reversed)
    case SNil{} _:
      String.reverse(reversed)
    case SCon{char, rest} 1n+left:
      take_text(rest, left, SCon{char, reversed})

def byte_count(bytes: List<&2, U32>, count: Nat) -> Nat:
  match bytes:
    case Nil{}:
      count
    case byte <> rest:
      byte_count(rest, 1n+count)

def byte_position(text: String, position: Nat) -> Nat:
  byte_count(Encode.bytes(Utf8.encode(take_text(text, position, ""))), 0n)

def positions(fuel: Nat, +map: Mapping.Mapping, +text: String, +position: Nat,
  ok: Bool) -> Bool:
  match fuel:
    case 0n:
      ok
    case 1n+rest:
      positions(rest, map, text, 1n+position,
        ok && equal(Mapping.to_byte(map, position), byte_position(text, position)))

def offset(value: Maybe<&2, Nat>) -> Nat:
  match value:
    case Some{position}:
      position
    case None{}:
      999999n

def missing(value: Maybe<&2, Nat>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def reverse_into(text: String, acc: String) -> String:
  match text:
    case SNil{}:
      acc
    case SCon{char, rest}:
      reverse_into(rest, SCon{char, acc})

def source_spans(spans: List<&2, Mapping.Span>, reversed: String) -> String:
  match spans:
    case Nil{}:
      String.reverse(reversed)
    case Mapping.Span{text, scalars, bytes} <> rest:
      source_spans(rest, reverse_into(text, reversed))

def map_source(map: Mapping.Mapping) -> String:
  match map:
    case Mapping.Mapping{scalars, bytes}:
      source_spans(Index.flatten(Mapping.Span, scalars, Nil{}), "")

def edited_case(value: Maybe<&2, Mapping.Mapping>, +expected: String) -> Bool:
  match value:
    case Some{+map}:
      Mapping.valid(map) && Text.text_equal(map_source(map), expected, True{}) &&
        equal(Mapping.to_byte(map, 2n), byte_position(expected, 2n)) &&
        equal(Mapping.to_byte(map, 129n), byte_position(expected, 129n)) &&
        equal(Mapping.to_byte(map, 999999n), byte_position(expected, 999999n))
    case None{}:
      False{}

def append_reversed(reversed: String, suffix: String) -> String:
  match reversed:
    case SNil{}:
      suffix
    case SCon{char, rest}:
      append_reversed(rest, SCon{char, suffix})

def append_text(text: String, suffix: String) -> String:
  append_reversed(String.reverse(text), suffix)

def replace_text(+text: String, +start: Nat, +end: Nat, insert: String) -> String:
  append_text(take_text(text, Nat.min(start, end), ""),
    append_text(insert, String.drop(text, Nat.max(start, end))))

def edit_ends(ends: List<&2, Nat>, +map: Mapping.Mapping, +text: String,
  +start: Nat, +insert: String, ok: Bool) -> Bool:
  match ends:
    case Nil{}:
      ok
    case +end <> rest:
      edit_ends(rest, map, text, start, insert, ok &&
        edited_case(Mapping.replace(map, start, end, insert), replace_text(text, start, end, insert)))

def edit_starts(starts: List<&2, Nat>, +ends: List<&2, Nat>, +map: Mapping.Mapping,
  +text: String, +insert: String, ok: Bool) -> Bool:
  match starts:
    case Nil{}:
      ok
    case start <> rest:
      edit_starts(rest, ends, map, text, insert, ok && edit_ends(ends, map, text, start, insert, True{}))

def repeat_text(fuel: Nat, +unit: String, text: String) -> String:
  match fuel:
    case 0n:
      text
    case 1n+rest:
      repeat_text(rest, unit, unit ++ text)

def large() -> IO(Unit):
  +source = repeat_text(16384n, String.repeat("x", 64n), "")
  +old = mapping(Mapping.from_text(source))
  +changed = Mapping.replace_spans(old, 4096n, 1n, mapping(Mapping.from_text("中😀")))
  +original_bytes = Encode.bytes(Utf8.encode(source))
  +buffer = Buffer.buffer(Bytes.from_bytes(original_bytes))
  +edited = Bytes.replace(buffer, offset(Mapping.to_byte(old, 524288n)),
    offset(Mapping.to_byte(old, 524416n)),
    Buffer.buffer(Bytes.from_bytes([228, 184, 173, 240, 159, 152, 128])))
  +inside = mapping(Mapping.replace(old, 524289n, 524293n, "中😀"))
  do IO<Unit>:
    Check.check(Mapping.valid(old) && Mapping.valid(changed))
    Check.check(Mapping.valid(inside))
    Check.check(equal(Mapping.to_byte(inside, 524289n), 524289n))
    Check.check(equal(Mapping.to_byte(inside, 524290n), 524292n))
    Check.check(equal(Mapping.to_byte(inside, 524291n), 524296n))
    Check.check(equal(Mapping.to_byte(inside, 1048574n), 1048579n))
    Check.check(Save.bytes_equal(Encode.bytes(Utf8.encode(map_source(inside))),
      Buffer.splice(original_bytes, 524289n, 524293n, [228, 184, 173, 240, 159, 152, 128])))
    Check.check(equal(Mapping.to_byte(old, 0n), 0n))
    Check.check(equal(Mapping.to_byte(old, 128n), 128n))
    Check.check(equal(Mapping.to_byte(old, 524288n), 524288n))
    Check.check(equal(Mapping.to_byte(old, 1048576n), 1048576n))
    Check.check(equal(Mapping.to_byte(old, 2097152n), 1048576n))
    Check.check(equal(Mapping.to_byte(changed, 524288n), 524288n))
    Check.check(equal(Mapping.to_byte(changed, 524289n), 524291n))
    Check.check(equal(Mapping.to_byte(changed, 524290n), 524295n))
    Check.check(equal(Mapping.to_byte(changed, 1048450n), 1048455n))
    Check.check(equal(Mapping.to_byte(old, 1048450n), 1048450n))
    Check.check(Save.bytes_equal(Bytes.materialize(edited),
      Buffer.splice(original_bytes, 524288n, 524416n, [228, 184, 173, 240, 159, 152, 128])))
    Check.check(Save.bytes_equal(Bytes.materialize(buffer), original_bytes))

def main() -> IO(Unit):
  +text = String.repeat("A中😀e\u{301}\0\r\n\u{feff}", 64n)
  +old = mapping(Mapping.from_text(text))
  +insert : String = "新😀\r\n"
  +added = mapping(Mapping.from_text(insert))
  +changed = Mapping.replace_spans(old, 1n, 1n, added)
  +expected = String.take(text, 128n) ++ insert ++ String.drop(text, 256n)
  +original_bytes = Encode.bytes(Utf8.encode(text))
  +buffer = Buffer.buffer(Bytes.from_bytes(original_bytes))
  +edited = Bytes.replace(buffer, offset(Mapping.to_byte(old, 128n)),
    offset(Mapping.to_byte(old, 256n)), Buffer.buffer(Bytes.from_bytes(Encode.bytes(Utf8.encode(insert)))))
  +ranges : List<&2, Nat> = [0n, 1n, 4n, 127n, 128n, 129n, 255n, 256n, 575n, 576n, 999n]
  do IO<Unit>:
    large()
    Check.check(edit_starts(ranges, ranges, old, text, insert, True{}))
    Check.check(edit_starts(ranges, ranges, old, text, "", True{}))
    Check.check(edited_case(Mapping.replace(old, 4n, 4n,
      repeat_text(1024n, "中文😀\r\n", "")), replace_text(text, 4n, 4n,
      repeat_text(1024n, "中文😀\r\n", ""))))
    Check.check(Mapping.valid(old) && Mapping.valid(added) && Mapping.valid(changed))
    Check.check(positions(577n, old, text, 0n, True{}))
    Check.check(positions(455n, changed, expected, 0n, True{}))
    Check.check(equal(Mapping.to_byte(old, 999999n), byte_position(text, 999999n)))
    Check.check(equal(Mapping.to_byte(mapping(Mapping.from_text("")), 5n), 0n))
    Check.check(Save.bytes_equal(Bytes.materialize(edited), Encode.bytes(Utf8.encode(expected))))
    Check.check(Save.bytes_equal(Bytes.materialize(buffer), original_bytes))
    Check.check(positions(577n, old, text, 0n, True{}))
    Check.check(missing(Mapping.to_byte(Mapping.Mapping{Index.Empty{},
      Index.Leaf{Mapping.Span{"x", 1n, 1n}, 1n}}, 0n)))
    IO.print("Unicode scalar to UTF-8 byte mapping and persistent span replacement check passed")
