import Base
import ../src/BlockScene.bend as Scene
import ../src/Blocks.bend as Blocks
import ../src/BlockIndex.bend as Index
import ./TextByteMapCheck.bend as Fixture
import ./LongLiteralCheck.bend as Literal
import ./Utf8Check.bend as Text
import ./DirectCheck.bend as Check

def parsed(value: List<&2, Blocks.Piece>, source: String) -> IO(Unit):
  match value:
    case [Blocks.Piece{Blocks.Fence{marker, width, True{}}, actual}]:
      do IO<Unit>:
        Check.check(Char.is_eq(marker, '`') && Nat.is_eq(width, 3n))
        Check.check(Text.text_equal(actual, source, True{}))
        IO.print("Long fence parsing passed")
    case _:
      IO.die(Unit, 1, "Long fence parsing failed")

def hidden(value: Scene.Scene, body: String) -> IO(Unit):
  match value:
    case Scene.Scene{[Scene.Run{text, style}], map}:
      do IO<Unit>:
        Check.check(Text.text_equal(text, body, True{}))
        Check.check(U32.is_eq(style, 3))
        Check.check(Literal.points(map, 65537n, 4n, 65545n, True{}))
        IO.print("Long fence hidden scene passed")
    case _:
      IO.die(Unit, 1, "Long fence scene shape failed")

def active(value: Scene.Scene, source: String) -> IO(Unit):
  match value:
    case Scene.Scene{[Scene.Run{text, style}], map}:
      do IO<Unit>:
        Check.check(Text.text_equal(text, source, True{}))
        Check.check(U32.is_eq(style, 3))
        Check.check(Literal.points(map, 65545n, 0n, 65545n, True{}))
        IO.print("Long fence active scene passed")
    case _:
      IO.die(Unit, 1, "Long fence active scene shape failed")

def main() -> IO(Unit):
  do IO<Unit>:
    +body : String = Scene.run_text([Scene.Run{Fixture.repeat_text(1024n, String.repeat("x", 64n), ""), 0}, Scene.Run{"\n", 0}])
    +source : String = Scene.run_text([Scene.Run{"```\n", 0}, Scene.Run{body, 0}, Scene.Run{"```\n", 0}])
    IO.print("Long fence parsing started")
    parsed(Blocks.parse(source), source)
    hidden(Scene.build(source, 65546n, 65546n), body)
    active(Scene.build(source, 0n, 0n), source)
