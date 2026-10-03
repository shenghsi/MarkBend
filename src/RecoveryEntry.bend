import Base
import ./SaveState.bend as Save
import ./RecoveryState.bend as Recovery
import ./RecoveryRecord.bend as Record

# The host supplies an exact, nonempty document identity. It is not a path to
# interpret here. Identity assignment and path resolution are host contracts.
type Entry is Data:
  Entry{key: List<&2, U32>, state: Save.State}

type Decision is Data:
  WrongDocument{entry: Entry, disk: List<&2, U32>}
  ForDocument{decision: Recovery.Decision}

def nonempty(bytes: List<&2, U32>) -> Bool:
  match bytes:
    case Nil{}:
      False{}
    case Con{head, tail}:
      True{}

def select(matches: Bool, entry: Entry, disk: List<&2, U32>) -> Decision:
  match matches:
    case False{}:
      WrongDocument{entry, disk}
    case True{}:
      match entry:
        case Entry{key, state}:
          ForDocument{Recovery.recover(state, disk)}

# The entry must come from decode. Matching source bytes alone is insufficient.
def recover(+requested: List<&2, U32>, +entry: Entry, disk: List<&2, U32>) -> Decision:
  match entry:
    case Entry{+key, state}:
      select(nonempty(requested) && Record.valid_bytes(requested) &&
        Save.bytes_equal(requested, key), entry, disk)

def prefix(key: String, payload: String) -> String:
  "MBE1\n" ++ key ++ "\n" ++ payload ++ "\n"

def encode_gate(ok: Bool, key: List<&2, U32>, payload: String) -> Maybe<&2, String>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Record.sealed(prefix(Record.bytes_text(key), payload))}

def encode(entry: Entry) -> Maybe<&2, String>:
  match entry:
    case Entry{+key, state}:
      do Maybe<&2, String>:
        payload : String <- Record.encode(state)
        encode_gate(nonempty(key) && Record.valid_bytes(key), key, payload)

def entry_gate(ok: Bool, key: List<&2, U32>, state: Save.State) -> Maybe<&2, Entry>:
  match ok:
    case True{}:
      Some{Entry{key, state}}
    case False{}:
      None{}

def entry_checked(+key: List<&2, U32>, state: Save.State) -> Maybe<&2, Entry>:
  entry_gate(nonempty(key), key, state)

def decode_gate(ok: Bool, key: String, payload: String) -> Maybe<&2, Entry>:
  match ok:
    case False{}:
      None{}
    case True{}:
      do Maybe<&2, Entry>:
        identity : List<&2, U32> <- Record.read_hex(key)
        state : Save.State <- Record.decode(payload)
        entry_checked(identity, state)

def decode_parts(parts: List<&2, String>) -> Maybe<&2, Entry>:
  match parts:
    case magic <> +key <> inner_magic <> next <> current <> saved <> id <> pending <>
      inner_check <> inner_end <> check <> end <> Nil{}:
      +payload = Record.prefix(inner_magic, next, current, saved, id, pending) ++
        inner_check ++ "\n" ++ inner_end
      decode_gate(String.eq(magic, "MBE1") && String.eq(end, "END") &&
        String.eq(check, U32.show(Record.hash(prefix(key, payload), 2166136261))), key, payload)
    case _:
      None{}

def decode(text: String) -> Maybe<&2, Entry>:
  decode_parts(Record.record_parts(text, "", Nil{}))
