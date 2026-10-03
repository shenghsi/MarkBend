import Base

type Decoder is Data:
  Decoder{remaining: U32, code: U32, minimum: U32, reversed: String, valid: Bool}

def between(+value: U32, low: U32, high: U32) -> Bool:
  U32.is_ge(value, low) && U32.is_le(value, high)

def scalar(+code: U32) -> Bool:
  U32.is_le(code, 1114111) && Bool.not(between(code, 55296, 57343))

def complete(ok: Bool, code: U32, reversed: String) -> Decoder:
  match ok:
    case True{}:
      Decoder{0, 0, 0, SCon{Char.from_u32(code), reversed}, True{}}
    case False{}:
      Decoder{0, 0, 0, reversed, False{}}

def continuation(last: Bool, +code: U32, +minimum: U32, remaining: U32,
  reversed: String) -> Decoder:
  match last:
    case True{}:
      complete(U32.is_ge(code, minimum) && scalar(code), code, reversed)
    case False{}:
      Decoder{U32.sub(remaining, 1), code, minimum, reversed, True{}}

def begin(ascii: Bool, two: Bool, three: Bool, four: Bool, byte: U32,
  reversed: String) -> Decoder:
  match ascii two three four:
    case True{} _ _ _:
      Decoder{0, 0, 0, SCon{Char.from_u32(byte), reversed}, True{}}
    case _ True{} _ _:
      Decoder{1, U32.sub(byte, 192), 128, reversed, True{}}
    case _ _ True{} _:
      Decoder{2, U32.sub(byte, 224), 2048, reversed, True{}}
    case _ _ _ True{}:
      Decoder{3, U32.sub(byte, 240), 65536, reversed, True{}}
    case _ _ _ _:
      Decoder{0, 0, 0, reversed, False{}}

def next(valid: Bool, idle: Bool, is_continuation: Bool, +byte: U32,
  +remaining: U32, code: U32, minimum: U32, reversed: String) -> Decoder:
  match valid idle is_continuation:
    case True{} True{} _:
      begin(U32.is_le(byte, 127), between(byte, 194, 223),
        between(byte, 224, 239), between(byte, 240, 244), byte, reversed)
    case True{} False{} True{}:
      continuation(U32.is_eq(remaining, 1),
        U32.add(U32.mul(code, 64), U32.sub(byte, 128)), minimum, remaining, reversed)
    case _ _ _:
      Decoder{0, 0, 0, reversed, False{}}

def advance(+byte: U32, state: Decoder) -> Decoder:
  match state:
    case Decoder{+remaining, code, minimum, reversed, valid}:
      next(valid, U32.is_eq(remaining, 0), between(byte, 128, 191), byte,
        remaining, code, minimum, reversed)

def finish(state: Decoder) -> Maybe<&2, String>:
  match state:
    case Decoder{0, code, minimum, reversed, True{}}:
      Some{String.reverse(reversed)}
    case _:
      None{}

def decode_go(bytes: List<&2, U32>, state: Decoder) -> Maybe<&2, String>:
  match bytes:
    case Nil{}:
      finish(state)
    case byte <> rest:
      decode_go(rest, advance(byte, state))

# Reject truncated sequences, overlong encodings, surrogate code points,
# non-byte values, and code points above U+10FFFF. Do not replace or normalize.
def decode(bytes: List<&2, U32>) -> Maybe<&2, String>:
  decode_go(bytes, Decoder{0, 0, 0, "", True{}})

def encoded(one: Bool, two: Bool, three: Bool, +code: U32,
  acc: List<&2, U32>) -> List<&2, U32>:
  match one two three:
    case True{} _ _:
      code <> acc
    case _ True{} _:
      U32.add(128, U32.mod(code, 64)) <> U32.add(192, U32.div(code, 64)) <> acc
    case _ _ True{}:
      U32.add(128, U32.mod(code, 64)) <>
        U32.add(128, U32.mod(U32.div(code, 64), 64)) <>
        U32.add(224, U32.div(code, 4096)) <> acc
    case _ _ _:
      U32.add(128, U32.mod(code, 64)) <>
        U32.add(128, U32.mod(U32.div(code, 64), 64)) <>
        U32.add(128, U32.mod(U32.div(code, 4096), 64)) <>
        U32.add(240, U32.div(code, 262144)) <> acc

def encode_finish(ok: Bool, acc: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      Some{List.reverse(&2, U32, acc)}
    case False{}:
      None{}

def encode_go(text: String, acc: List<&2, U32>, ok: Bool) -> Maybe<&2, List<&2, U32>>:
  match text:
    case SNil{}:
      encode_finish(ok, acc)
    case SCon{Chr{+code}, rest}:
      encode_go(rest, encoded(U32.is_le(code, 127), U32.is_le(code, 2047),
        U32.is_le(code, 65535), code, acc), ok && scalar(code))

def encode(text: String) -> Maybe<&2, List<&2, U32>>:
  encode_go(text, Nil{}, True{})
