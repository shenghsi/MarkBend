import Base
import ../src/TextRelease.bend as Release
import ../src/TextStorage.bend as Storage
import ./TextStorageCheck.bend as Text
import ./TextByteMapCheck.bend as Mapping
import ./DirectCheck.bend as Check

def drained(fuel: Nat, value: Release.Progress) -> Bool:
  match fuel value:
    case _ Release.Complete{}:
      True{}
    case 0n _:
      False{}
    case 1n+remaining Release.Pending{queue}:
      drained(remaining, Release.step(32n, queue))

def main() -> IO(Unit):
  +source : String = "中😀é\0\r\n"
  +original = Text.snapshot(Storage.from_text(source))
  +changed = Text.accepted(Storage.replace(original, 0n, 1n, "新"))
  +large_source = Mapping.repeat_text(16384n, String.repeat("x", 64n), "")
  +large = Text.snapshot(Storage.from_text(large_source))
  do IO<Unit>:
    Check.check(drained(4n, Release.step(1n, Release.begin(changed))))
    Check.check(Text.matches(original, source))
    Check.check(Text.matches(changed, "新😀é\0\r\n"))
    Check.check(drained(2048n, Release.step(32n, Release.begin(large))))
    Check.check(Text.matches(large, large_source))
    Check.check(drained(2n, Release.step(8n, Release.begin(Text.snapshot(Storage.from_text(""))))))
    IO.print("Text storage release slices and retained Unicode snapshots check passed")
