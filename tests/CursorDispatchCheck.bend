import Base
import ../src/CursorMap.bend as Cursor
import ../src/ScalarText.bend as Scalar
import ./DirectCheck.bend as Check

def points(value: List<&2, Nat>, count: Nat, +offset: Nat, ok: Bool) -> Bool:
  match value count ok:
    case _ _ False{}:
      False{}
    case Nil{} 0n True{}:
      True{}
    case point <> rest 1n+remaining True{}:
      points(rest, remaining, 1n+offset, Nat.is_eq(point, offset))
    case _ _ _:
      False{}

def verified(value: Cursor.Chunk, +count: Nat) -> Bool:
  match value:
    case Cursor.Chunk{map, Nil{}, finish}:
      points(map, count, 1n, True{}) && Nat.is_eq(finish, 1n+count)
    case _:
      False{}

def run(+size: Nat) -> IO(Unit):
  +visible = "*" ++ String.repeat("x", Nat.sub(size, 1n))
  +source = "\\*" ++ String.repeat("x", Nat.sub(size, 1n))
  +short_source = "\\*" ++ String.repeat("x", Nat.sub(size, 2n))
  do IO<Unit>:
    Check.check(verified(Cursor.consume(Scalar.to_chars(visible), Scalar.to_chars(source), 0n, True{}), size))
    Check.check(verified(Cursor.consume(Scalar.to_chars(visible), Scalar.to_chars(short_source), 0n, True{}), Nat.sub(size, 1n)))

def main() -> IO(Unit):
  do IO<Unit>:
    run(127n)
    run(128n)
    run(129n)
    IO.print("Cursor dispatch boundary check passed")
