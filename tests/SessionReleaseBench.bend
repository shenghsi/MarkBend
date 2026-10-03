import Base
import ../src/SessionRelease.bend as Release
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./SessionDisposeBench.bend as Dispose
import ./StoredTypingBench.bend as Typing
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def main() -> IO(Unit):
  +source = Fixture.sample(1048576n)
  initial = Save.open(Encode.bytes(Utf8.encode(source)))
  do IO<Unit>:
    base : Editor.Session <- Dispose.loaded(Editor.load(initial))
    changed : Editor.Session <- Dispose.edits(20n, base)
    restored : Editor.Session = Typing.undo(20n, changed)
    +start : Nat <- IO.now()
    ticket : Chan(Bool) <- Release.begin(restored)
    +queued : Nat <- IO.now()
    IO.sleep(10)
    +heartbeat : Nat <- IO.now()
    done : Bool <- Release.finish(ticket)
    +end : Nat <- IO.now()
    Check.check(done)
    IO.print("session_deferred_release dispatch_ms=" ++ Nat.show(Nat.sub(queued, start)) ++
      " heartbeat_ms=" ++ Nat.show(Nat.sub(heartbeat, queued)) ++
      " heartbeat_delay_ms=" ++ Nat.show(Nat.sub(Nat.sub(heartbeat, queued), 10n)) ++
      " completion_ms=" ++ Nat.show(Nat.sub(end, start)))
    IO.print("Deferred persistent session release check passed")
