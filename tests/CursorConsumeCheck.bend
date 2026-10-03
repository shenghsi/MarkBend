import Base
import ../src/CursorMap.bend as Cursor
import ./SessionViewCheck.bend as View
import ./DirectCheck.bend as Check

def verified(value: Cursor.Chunk, points: List<&2, Nat>, chars: List<&2, Char>,
  offset: Nat) -> Bool:
  match value:
    case Cursor.Chunk{actual, remaining, finish}:
      View.same_points(actual, points) && List.is_empty(&2, Char, remaining) &&
        List.is_empty(&2, Char, chars) && Nat.is_eq(finish, offset)

def main() -> IO(Unit):
  do IO<Unit>:
    Check.check(verified(Cursor.consume(['*', '`'], [Chr{92}, '*', Chr{92}, '`'], 3n, True{}), [4n, 6n], Nil{}, 7n))
    Check.check(verified(Cursor.consume(['*', '`'], [Chr{92}, '*'], 0n, False{}), [0n, 1n], Nil{}, 2n))
    Check.check(verified(Cursor.consume(['a', 'b', 'c'], ['a', 'b'], 0n, True{}), [0n, 1n], Nil{}, 2n))
    Check.check(verified(Cursor.consume(Nil{}, Nil{}, 5n, True{}), Nil{}, Nil{}, 5n))
    IO.print("Cursor consumption check passed")
