import Base
import ../src/SessionRelease.bend as Release
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ./SessionDisposeBench.bend as Dispose
import ./StoredEditorCheck.bend as Correct
import ./DirectCheck.bend as Check

def main() -> IO(Unit):
  +initial = Save.open([228,184,173])
  do IO<Unit>:
    +opened : Editor.Session <- Dispose.loaded(Editor.load(initial))
    changed : Editor.Session <- Dispose.edits(2n, opened)
    ticket : Chan(Bool) <- Release.begin(changed)
    Check.check(Correct.matches(opened, "中", Save.request(initial)))
    done : Bool <- Release.finish(ticket)
    Check.check(done)
    Check.check(Correct.matches(opened, "中", Save.request(initial)))
    IO.print("Deferred session release preserves retained snapshots check passed")
