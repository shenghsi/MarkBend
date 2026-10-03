import Base
import ../src/EditorRelease.bend as Release
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ./StoredEditorCheck.bend as Session
import ./SessionDisposeBench.bend as Dispose
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
  +initial = Save.open([228,184,173,13,10])
  do IO<Unit>:
    +opened : Editor.Session <- Session.loaded(Editor.load(initial))
    +first : Editor.Session <- Session.accepted(Editor.edit(opened, 0n, 0n, "X"))
    +saving : Editor.Session <- IO.pure(Editor.Session, Editor.request(first))
    +changed : Editor.Session <- Dispose.edits(2n, saving)
    owned : Release.Progress <- Release.drain(0n, 32n, Release.begin(Editor.undo(changed)))
    Check.check(drained(1024n, owned))
    Check.check(drained(1024n, Release.step(32n, Release.begin(Editor.undo(changed)))))
    Check.check(Session.matches(opened, "中\r\n", initial))
    Check.check(Session.matches(first, "X中\r\n", Save.edit(initial, [88,228,184,173,13,10])))
    Check.check(Session.matches(changed, "XXX中\r\n",
      Save.edit(Save.request(Save.edit(initial, [88,228,184,173,13,10])), [88,88,88,228,184,173,13,10])))
    Check.check(drained(1024n, Release.step(32n, Release.begin(Editor.clear_history(changed)))))
    IO.print("Complete editor release preserves retained sessions and save requests check passed")
