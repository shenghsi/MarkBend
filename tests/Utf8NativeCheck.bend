import Base
import ../src/Utf8.bend as Utf8
import ../src/TextByteMap.bend as Mapping
import ../src/TextStorage.bend as Storage
import ../src/SaveState.bend as Save
import ../src/ByteBuffer.bend as Bytes
import ../src/BlockIndex.bend as Index
import ./Utf8Check.bend as Utf8Check
import ./DirectCheck.bend as Check

# The JavaScript runtime rejects these Char values at construction time.
def rejected_map(value: Maybe<&2, Mapping.Mapping>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def storage(value: Maybe<&2, Storage.Snapshot>) -> Storage.Snapshot:
  match value:
    case Some{snapshot}:
      snapshot
    case None{}:
      Storage.Snapshot{Bytes.Buffer{Index.Empty{}}, Mapping.Mapping{Index.Empty{}, Index.Empty{}}}

def rejected_edit(value: Storage.EditResult) -> Bool:
  match value:
    case Storage.Rejected{+snapshot}:
      Storage.valid(snapshot) && Save.bytes_equal(Storage.materialize(snapshot), [120])
    case _:
      False{}

def main() -> IO(Unit):
  +map = Mapping.build([Mapping.span("x")])
  +original = storage(Storage.from_text("x"))
  do IO<Unit>:
    Check.check(Utf8Check.rejected_text(Utf8.encode(SCon{Chr{55296}, SNil{}})))
    Check.check(Utf8Check.rejected_text(Utf8.encode(SCon{Chr{1114112}, SNil{}})))
    Check.check(rejected_map(Mapping.from_text(SCon{Chr{55296}, SNil{}})))
    Check.check(rejected_map(Mapping.from_text(SCon{Chr{1114112}, SNil{}})))
    Check.check(rejected_map(Mapping.replace(map, 0n, 0n, SCon{Chr{55296}, SNil{}})))
    Check.check(rejected_map(Mapping.replace(map, 0n, 1n, SCon{Chr{1114112}, SNil{}})))
    Check.check(Mapping.valid(map))
    Check.check(rejected_edit(Storage.replace(original, 0n, 0n, SCon{Chr{55296}, SNil{}})))
    Check.check(rejected_edit(Storage.replace(original, 0n, 1n, SCon{Chr{1114112}, SNil{}})))
    IO.print("Native invalid Unicode character encoding check passed")
