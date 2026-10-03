import Base
import ../src/SceneRelease.bend as Release
import ../src/DirectState.bend as Editor
import ./Utf8Check.bend as Text
import ./DirectCheck.bend as Check
import ../src/BlockScene.bend as Scene
import ./TextByteMapCheck.bend as Fixture
import ./SessionViewCheck.bend as View

def projection(value: Editor.View, source: String, start: Nat, end: Nat) -> Bool:
  match value:
    case Editor.View{scene, visible}:
      View.same_scene(scene, Scene.build(source, start, end))

def drained(fuel: Nat, value: Release.Progress) -> Bool:
  match fuel value:
    case _ Release.Complete{}:
      True{}
    case 0n _:
      False{}
    case 1n+remaining Release.Pending{queue}:
      drained(remaining, Release.step(32n, queue))

def points(count: Nat, acc: List<&2, Nat>) -> List<&2, Nat>:
  match count:
    case 0n:
      acc
    case 1n+ +remaining:
      points(remaining, remaining <> acc)

def long_native() -> IO(Unit):
  do IO<Unit>:
    IO.print("Long paragraph opening started")
    +long : Editor.Session <- IO.pure(Editor.Session, Editor.start(Fixture.repeat_text(1024n, String.repeat("x", 64n), "")))
    IO.print("Long paragraph opening completed")
    Check.check(drained(8192n, Release.step(32n, Release.begin(long))))
    Check.check(Text.text_equal(Editor.source(Editor.current(long)), Fixture.repeat_text(1024n, String.repeat("x", 64n), ""), True{}))
    IO.print("Native long paragraph release check passed")

def main() -> IO(Unit):
  +source : String = "# 中文😀\r\n\r\n**ab** é\0\n- item\n```\ncode\n```\n"
  +opened = Editor.start(source)
  +first = Editor.edit(opened, 0n, 0n, "X")
  +second = Editor.edit(first, 0n, 0n, "Y")
  +long_text = Fixture.repeat_text(1024n, String.repeat("x", 64n), "")
  do IO<Unit>:
    Check.check(drained(4096n, Release.step(32n, Release.begin(Editor.undo(second)))))
    Check.check(Text.text_equal(Editor.source(Editor.current(opened)), source, True{}))
    Check.check(Text.text_equal(Editor.source(Editor.current(first)), "X" ++ source, True{}))
    Check.check(Text.text_equal(Editor.source(Editor.current(second)), "YX" ++ source, True{}))
    Check.check(projection(Editor.view(opened), source, 0n, 0n))
    Check.check(projection(Editor.view(first), "X" ++ source, 1n, 1n))
    Check.check(projection(Editor.view(second), "YX" ++ source, 1n, 1n))
    Check.check(drained(8192n, Release.step(32n, Release.Queue{[
      Release.Text{long_text}, Release.Runs{[Scene.Run{long_text, 0}]},
      Release.Points{points(65536n, Nil{})}]})))
    Check.check(Text.text_equal(long_text, Fixture.repeat_text(1024n, String.repeat("x", 64n), ""), True{}))
    Check.check(drained(16n, Release.step(32n, Release.begin(Editor.start("")))))
    IO.print("Formatted document and scene release preserves retained snapshots check passed")
