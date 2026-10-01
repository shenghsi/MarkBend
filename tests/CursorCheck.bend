import Base
import ../CursorMap.bend as Cursor

def show(points: List<&2, Nat>) -> String:
  match points:
    case Nil{}:
      "end"
    case point <> rest:
      Nat.show(point) ++ "," ++ show(rest)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(show(Cursor.mapping("a **bc** *d* `e`")))
    IO.print(show(Cursor.mapping("中文\\*\n")))
    IO.print(show(Cursor.mapping("**a\\*")))
    IO.print(Nat.show(Cursor.to_source(Cursor.mapping("**ab**"), 100n)))
    IO.print(Nat.show(Cursor.to_view(Cursor.mapping("**ab**"), 5n)))
