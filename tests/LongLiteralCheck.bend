import Base
import ../src/BlockScene.bend as Scene
import ./TextByteMapCheck.bend as Fixture
import ./Utf8Check.bend as Text
import ./DirectCheck.bend as Check

def points(value: List<&2, Nat>, count: Nat, +offset: Nat, +finish: Nat,
  ok: Bool) -> Bool:
  match value count ok:
    case _ _ False{}:
      False{}
    case actual <> Nil{} 0n True{}:
      Nat.is_eq(actual, finish)
    case actual <> rest 1n+remaining True{}:
      points(rest, remaining, 1n+offset, finish, Nat.is_eq(actual, offset))
    case _ _ _:
      False{}

def verified(value: Scene.Scene, source: String) -> IO(Unit):
  match value:
    case Scene.Scene{[Scene.Run{text, style}], map}:
      do IO<Unit>:
        Check.check(Text.text_equal(text, source, True{}))
        Check.check(U32.is_eq(style, 3))
        Check.check(points(map, 65536n, 5n, 999999n, True{}))
        IO.print("Long literal exact text and map check passed")
    case _:
      IO.die(Unit, 1, "Long literal run shape failed")

def main() -> IO(Unit):
  do IO<Unit>:
    +source : String = Fixture.repeat_text(8192n, "中文😀é\r\n\0", "")
    IO.print("Long literal construction started")
    verified(Scene.literal(source, 5n, 999999n, 3), source)
