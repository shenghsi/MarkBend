import Base
import ./CursorMap.bend as Cursor
import ./ScalarText.bend as Scalar

# Native AppKit and JavaScript positions count UTF-16 code units.
# Bend strings count Unicode scalars. Never split a surrogate pair.
def width_result(wide: Bool) -> Nat:
  match wide:
    case True{}:
      2n
    case False{}:
      1n

def width(char: Char) -> Nat:
  width_result(U32.is_gt(Char.to_u32(char), 65535))

def boundaries(text: String, +offset: Nat) -> List<&2, Nat>:
  match text:
    case SNil{}:
      [offset]
    case SCon{char, rest}:
      offset <> boundaries(rest, Nat.add(offset, width(char)))

def native_scan(text: String, scalar: Nat, offset: Nat) -> Nat:
  match text scalar:
    case SNil{} _:
      offset
    case _ 0n:
      offset
    case SCon{char, rest} 1n+remaining:
      native_scan(rest, remaining, Nat.add(offset, width(char)))

def to_native(text: String, scalar: Nat) -> Nat:
  native_scan(text, scalar, 0n)

def scalar_step(done: Bool, scalar: Nat, later: Unit -> Nat) -> Nat:
  match done:
    case True{}:
      scalar
    case False{}:
      later(Unit{})

def scalar_scan(text: String, +native: Nat, +scalar: Nat) -> Nat:
  match text native:
    case SNil{} _:
      scalar
    case _ 0n:
      scalar
    case SCon{char, rest} _:
      +units = width(char)
      scalar_step(Nat.is_le(native, units), 1n+scalar,
        _ => scalar_scan(rest, Nat.sub(native, units), 1n+scalar))

# A position inside a surrogate pair maps to the following scalar boundary.
def to_scalar(text: String, native: Nat) -> Nat:
  scalar_scan(text, native, 0n)

def drop_scalars(text: String, count: Nat) -> String:
  match text count:
    case _ 0n:
      text
    case SNil{} _:
      ""
    case SCon{char, rest} 1n+remaining:
      drop_scalars(rest, remaining)

def replaced_prefix(prefix: List<&2, Char>, insert: String, suffix: String) -> String:
  Scalar.from_reversed(prefix,
    Scalar.from_reversed(List.reverse(&2, Char, Scalar.to_chars(insert)), suffix))

def replace_prefix(text: String, start: Nat, removed: Nat, insert: String,
  reversed: List<&2, Char>) -> String:
  match text start:
    case _ 0n:
      replaced_prefix(reversed, insert, drop_scalars(text, removed))
    case SNil{} _:
      replaced_prefix(reversed, insert, "")
    case SCon{char, rest} 1n+remaining:
      replace_prefix(rest, remaining, removed, insert, char <> reversed)

# Replace a scalar range with tail loops. Reversed selections have the same result.
def ordered_replace(text: String, +start: Nat, end: Nat, insert: String) -> String:
  replace_prefix(text, start, Nat.sub(end, start), insert, Nil{})

def replace_order(same_order: Bool, text: String, start: Nat, end: Nat, insert: String) -> String:
  match same_order:
    case True{}:
      ordered_replace(text, start, end, insert)
    case False{}:
      ordered_replace(text, end, start, insert)

def replace(+text: String, +start: Nat, +end: Nat, insert: String) -> String:
  replace_order(Nat.is_le(start, end), text, start, end, insert)
