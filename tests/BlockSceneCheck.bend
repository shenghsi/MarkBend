import Base
import ../src/BlockScene.bend as Scene
import ../src/DirectState.bend as State
import ../src/CursorMap.bend as Cursor
import ./DirectCheck.bend as Check

def main() -> IO(Unit):
  +source = {"# h\n\n```rs\n**x** *y* `z`\n```\n\ntail" : String}
  +inactive = Scene.build(source, 32n, 32n)
  +active = Scene.build(source, 12n, 12n)
  +selected = State.select(State.start(source), 6n, 6n)
  +edited = State.edit(selected, 10n, 11n, "X")
  do IO<Unit>:
    Check.check(String.eq(Scene.text(inactive), "h\n\n**x** *y* `z`\n\ntail"))
    Check.check(Nat.is_eq(Cursor.to_source(Scene.points(inactive), 3n), 11n))
    Check.check(String.eq(Scene.text(active), "h\n\n```rs\n**x** *y* `z`\n```\n\ntail"))
    Check.check(Check.snapshot_is(State.current(selected), source, 12n, 12n))
    Check.check(Check.snapshot_is(State.current(edited),
      "# h\n\n```rs\n*Xx** *y* `z`\n```\n\ntail", 13n, 13n))
    Check.check(Check.snapshot_is(State.current(State.undo(edited)), source, 12n, 12n))
    Check.check(String.eq(Scene.text(Scene.build("**a**\n\n**b**", 0n, 0n)), "**a**\n\nb"))
    Check.check(String.eq(Scene.text(Scene.build("#\n\ntail", 5n, 5n)), "\n\ntail"))
    Check.check(String.eq(Scene.text(Scene.build("##\t中文\r\n\nlast", 12n, 12n)), "中文\r\n\nlast"))
    Check.check(String.eq(Scene.text(Scene.build("~~~\n*x*\n", 0n, 0n)), "~~~\n*x*\n"))
    IO.print("Block scene batch passed")
