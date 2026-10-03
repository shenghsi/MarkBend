import Base
import ../src/TextPosition.bend as Position
import ../src/CursorMap.bend as Cursor

def check(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "Text position check failed")

def scan(remaining: Nat, +text: String, +index: Nat) -> IO(Unit):
  match remaining:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        check(Nat.is_eq(Position.to_scalar(text, Position.to_native(text, index)), index))
        scan(rest, text, 1n+index)

# The boundary list is the simple reference model. Production conversions now
# walk only to the requested position and do not allocate this list.
def differential(fuel: Nat, +text: String, +index: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      +boundaries = Position.boundaries(text, 0n)
      do IO<Unit>:
        check(Nat.is_eq(Position.to_native(text, index), Cursor.to_source(boundaries, index)))
        check(Nat.is_eq(Position.to_scalar(text, index), Cursor.to_view(boundaries, index)))
        differential(rest, text, 1n+index)

def main() -> IO(Unit):
  do IO<Unit>:
    scan(8n, "a😀中文é\n", 0n)
    differential(4n, "", 0n)
    differential(30n, "a😀中文é\n👩‍💻🇯🇵", 0n)
    differential(12n, "😀😀😀", 0n)
    check(Nat.is_eq(Position.to_native("a😀b", 2n), 3n))
    check(Nat.is_eq(Position.to_scalar("a😀b", 2n), 2n))
    check(Nat.is_eq(Position.to_native("a😀b", 100n), 4n))
    check(Nat.is_eq(Position.to_scalar("a😀b", 100n), 3n))
    check(String.eq(Position.replace("a😀中文b", 1n, 4n, "日\n"), "a日\nb"))
    check(String.eq(Position.replace("a😀中文b", 4n, 1n, "日\n"), "a日\nb"))
    check(String.eq(Position.replace("中文", 100n, 101n, "!"), "中文!"))
    IO.print("Text position batch passed")
