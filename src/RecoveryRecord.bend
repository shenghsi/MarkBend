import Base
import ./SaveState.bend as Save

# Version 2 stores two lowercase hexadecimal characters for each byte.
# The decoder also accepts version 1 decimal records.
def hex_digit_gate(decimal: Bool, value: U32) -> Char:
  match decimal:
    case True{}:
      Chr{(value + 48 : U32)}
    case False{}:
      Chr{(value + 87 : U32)}

def hex_digit(+value: U32) -> Char:
  hex_digit_gate(U32.is_lt(value, 10), value)

def bytes_text_reverse(bytes: List<&2, U32>, acc: String) -> String:
  match bytes:
    case Nil{}:
      String.reverse(acc)
    case Con{+byte, rest}:
      bytes_text_reverse(rest, SCon{hex_digit(U32.and(byte, 15)),
        SCon{hex_digit(U32.shrn(byte, 4n)), acc}})

def bytes_text(bytes: List<&2, U32>) -> String:
  bytes_text_reverse(bytes, "")

def valid_bytes_go(bytes: List<&2, U32>, ok: Bool) -> Bool:
  match bytes ok:
    case Nil{} True{}:
      True{}
    case Con{byte, rest} True{}:
      valid_bytes_go(rest, U32.is_lt(byte, 256))
    case _ False{}:
      False{}

def valid_bytes(bytes: List<&2, U32>) -> Bool:
  valid_bytes_go(bytes, True{})

def hash(text: String, acc: U32) -> U32:
  match text:
    case SNil{}:
      acc
    case SCon{Chr{code}, rest}:
      hash(rest, ((acc .^. code) * 16777619 : U32))

def prefix(magic: String, next: String, current: String, saved: String, id: String, pending: String) -> String:
  magic ++ "\n" ++ next ++ "\n" ++ current ++ "\n" ++ saved ++ "\n" ++ id ++ "\n" ++ pending ++ "\n"

def sealed(+text: String) -> String:
  text ++ U32.show(hash(text, 2166136261)) ++ "\nEND"

def pending_text(pending: Maybe<&2, Save.Ticket>) -> String & String:
  match pending:
    case None{}:
      ("-", "")
    case Some{Save.Ticket{id, bytes}}:
      (Nat.show(id), bytes_text(bytes))

def encode_fields(next: Nat, current: List<&2, U32>, saved: List<&2, U32>,
  pending: String & String) -> String:
  match pending:
    case (id, bytes):
      sealed(prefix("MBR2", Nat.show(next), bytes_text(current), bytes_text(saved), id, bytes))

def encode_raw(state: Save.State) -> String:
  match state:
    case Save.State{current, saved, next, pending}:
      encode_fields(next, current, saved, pending_text(pending))

def valid_pending(pending: Maybe<&2, Save.Ticket>, next: Nat) -> Bool:
  match pending:
    case None{}:
      True{}
    case Some{Save.Ticket{id, bytes}}:
      Nat.is_lt(id, next) && valid_bytes(bytes)

def valid(state: Save.State) -> Bool:
  match state:
    case Save.State{current, saved, +next, pending}:
      valid_bytes(current) && valid_bytes(saved) &&
        Nat.is_le(next, Nat.add(Nat.mul(U32.to_nat(4294967295), 65536n), 65535n)) &&
        valid_pending(pending, next)

def encode_gate(ok: Bool, state: Save.State) -> Maybe<&2, String>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{encode_raw(state)}

def encode(+state: Save.State) -> Maybe<&2, String>:
  encode_gate(valid(state), state)

def byte_gate(ok: Bool, byte: U32) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{byte}
    case False{}:
      None{}

def byte_checked(+byte: U32) -> Maybe<&2, U32>:
  byte_gate(U32.is_lt(byte, 256), byte)

def read_bytes(parts: List<&2, String>) -> Maybe<&2, List<&2, U32>>:
  match parts:
    case Con{SNil{}, Nil{}}:
      Some{Nil{}}
    case Con{head, rest}:
      do Maybe<&2, List<&2, U32>>:
        value : U32 <- U32.read(head)
        byte : U32 <- byte_checked(value)
        bytes : List<&2, U32> <- read_bytes(rest)
        return Con{byte, bytes}
    case Nil{}:
      None{}

def read_digit_gate(decimal: Bool, letter: Bool, code: U32) -> Maybe<&2, U32>:
  match decimal letter:
    case True{} _:
      Some{(code - 48 : U32)}
    case False{} True{}:
      Some{(code - 87 : U32)}
    case False{} False{}:
      None{}

def read_digit(+code: U32) -> Maybe<&2, U32>:
  read_digit_gate(U32.is_ge(code, 48) && U32.is_le(code, 57),
    U32.is_ge(code, 97) && U32.is_le(code, 102), code)

# Invalid digits use a value outside the nibble range. The next tail-call
# validation flag rejects them before a byte list can be returned.
def digit_value(value: Maybe<&2, U32>) -> U32:
  match value:
    case Some{digit}:
      digit
    case None{}:
      256

def read_hex_go(text: String, acc: List<&2, U32>, ok: Bool) -> Maybe<&2, List<&2, U32>>:
  match text ok:
    case SNil{} True{}:
      Some{List.reverse(&2, U32, acc)}
    case SCon{Chr{high}, SCon{Chr{low}, rest}} True{}:
      +h = digit_value(read_digit(high))
      +l = digit_value(read_digit(low))
      read_hex_go(rest, Con{(h * 16 + l : U32), acc}, U32.is_lt(h, 16) && U32.is_lt(l, 16))
    case _ _:
      None{}

def read_hex(text: String) -> Maybe<&2, List<&2, U32>>:
  read_hex_go(text, Nil{}, True{})

def read_payload(hex: Bool, text: String) -> Maybe<&2, List<&2, U32>>:
  match hex:
    case True{}:
      read_hex(text)
    case False{}:
      read_bytes(String.split(text, ','))

def read_pending(hex: Bool, id: String, bytes: String) -> Maybe<&2, Maybe<&2, Save.Ticket>>:
  match id bytes:
    case SCon{'-', SNil{}} SNil{}:
      Some{None{}}
    case id bytes:
      do Maybe<&2, Maybe<&2, Save.Ticket>>:
        ticket : Nat <- Nat.read(id)
        payload : List<&2, U32> <- read_payload(hex, bytes)
        return Some{Save.Ticket{ticket, payload}}

def state_gate(ok: Bool, state: Save.State) -> Maybe<&2, Save.State>:
  match ok:
    case True{}:
      Some{state}
    case False{}:
      None{}

def state_checked(+state: Save.State) -> Maybe<&2, Save.State>:
  state_gate(valid(state), state)

def decode_fields(+hex: Bool, next: String, current: String, saved: String, id: String,
  pending: String) -> Maybe<&2, Save.State>:
  do Maybe<&2, Save.State>:
    n : Nat <- Nat.read(next)
    c : List<&2, U32> <- read_payload(hex, current)
    s : List<&2, U32> <- read_payload(hex, saved)
    p : Maybe<&2, Save.Ticket> <- read_pending(hex, id, pending)
    state_checked(Save.State{c, s, n, p})

def decode_checked(ok: Bool, hex: Bool, next: String, current: String, saved: String,
  id: String, pending: String) -> Maybe<&2, Save.State>:
  match ok:
    case False{}:
      None{}
    case True{}:
      decode_fields(hex, next, current, saved, id, pending)

def decode_parts(parts: List<&2, String>) -> Maybe<&2, Save.State>:
  match parts:
    case +magic <> +next <> +current <> +saved <> +id <> +pending <> check <> end <> Nil{}:
      decode_checked((String.eq(magic, "MBR1") || String.eq(magic, "MBR2")) && String.eq(end, "END") &&
        String.eq(check, U32.show(hash(prefix(magic, next, current, saved, id, pending), 2166136261))),
        String.eq(magic, "MBR2"), next, current, saved, id, pending)
    case _:
      None{}

def record_parts(text: String, part: String, parts: List<&2, String>) -> List<&2, String>:
  match text:
    case SNil{}:
      List.reverse(&2, String, Con{String.reverse(part), parts})
    case SCon{'\n', rest}:
      record_parts(rest, "", Con{String.reverse(part), parts})
    case SCon{head, rest}:
      record_parts(rest, SCon{head, part}, parts)

def decode(text: String) -> Maybe<&2, Save.State>:
  decode_parts(record_parts(text, "", Nil{}))
