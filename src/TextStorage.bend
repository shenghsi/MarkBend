import Base
import ./ByteBuffer.bend as Bytes
import ./TextByteMap.bend as Mapping
import ./Utf8.bend as Utf8
import ./BlockIndex.bend as Index

type Snapshot is Data:
  Snapshot{bytes: Bytes.Buffer, mapping: Mapping.Mapping}

type EditResult is Data:
  Accepted{snapshot: Snapshot}
  Rejected{snapshot: Snapshot}

def from_text_and_bytes(+text: String, bytes: List<&2, U32>) -> Maybe<&2, Snapshot>:
  do Maybe<&2, Snapshot>:
    buffer : Bytes.Buffer <- Bytes.from_bytes(bytes)
    map : Mapping.Mapping <- Mapping.from_text(text)
    return Snapshot{buffer, map}

# Bytes are authoritative. The scalar map is a cache built from strict decode.
# Invalid UTF-8 returns None; the caller must retain the original input bytes.
def from_bytes(+bytes: List<&2, U32>) -> Maybe<&2, Snapshot>:
  do Maybe<&2, Snapshot>:
    text : String <- Utf8.decode(bytes)
    from_text_and_bytes(text, bytes)

def from_text(+text: String) -> Maybe<&2, Snapshot>:
  do Maybe<&2, Snapshot>:
    bytes : List<&2, U32> <- Utf8.encode(text)
    from_text_and_bytes(text, bytes)

def inserted(value: Maybe<&2, Bytes.Buffer>, original: Snapshot,
  map: Mapping.Mapping, start: Nat, end: Nat) -> EditResult:
  match value original:
    case Some{added} Snapshot{bytes, old_map}:
      Accepted{Snapshot{Bytes.replace(bytes, start, end, added), map}}
    case None{} original:
      Rejected{original}

def edited(original: Snapshot, map: Maybe<&2, Mapping.Mapping>,
  insert: Maybe<&2, List<&2, U32>>, start: Maybe<&2, Nat>, end: Maybe<&2, Nat>) -> EditResult:
  match map insert start end:
    case Some{map} Some{bytes} Some{start} Some{end}:
      inserted(Bytes.from_bytes(bytes), original, map, start, end)
    case _ _ _ _:
      Rejected{original}

# Positions count source scalars. Native UTF-16 positions must be mapped first.
# Encode only inserted text and rebuild only boundary spans and byte chunks.
# Saved, pending, and history snapshots can keep their previous roots.
def replace(+original: Snapshot, +start: Nat, +end: Nat, +insert: String) -> EditResult:
  match original:
    case Snapshot{bytes, +map}:
      first last = Mapping.to_byte(map, Nat.min(start, end))
        Mapping.to_byte(map, Nat.max(start, end))
      next encoded = Mapping.replace(map, start, end, insert) Utf8.encode(insert)
      edited(original, next, encoded, first, last)

def materialize(snapshot: Snapshot) -> List<&2, U32>:
  match snapshot:
    case Snapshot{bytes, map}:
      Bytes.materialize(bytes)

def map_bytes(map: Mapping.Mapping) -> Nat:
  match map:
    case Mapping.Mapping{scalars, bytes}:
      Index.length(Mapping.Span, bytes)

# Structural validation. Tests also compare the complete cached text encoding
# with authoritative bytes. Use constructors and replace to keep them coherent.
def valid(snapshot: Snapshot) -> Bool:
  match snapshot:
    case Snapshot{+bytes, +map}:
      Bytes.valid(bytes) && Mapping.valid(map) &&
        Nat.is_eq(map_bytes(map), Bytes.length(bytes))
