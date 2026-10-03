import Base
import ../src/EditorRelease.bend as Release
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./SessionDisposeBench.bend as Session
import ./StoredTypingBench.bend as History
import ./EditorReleaseHeartbeat.bend as Heartbeat
import ./NativeStoredCheck.bend as Native
import ./DirectCheck.bend as Check

# Use the existing native driver for selection, text input, composition,
# undo, and redo while a separate, owned editor session is released.
def run(+pause: U32) -> IO(Unit):
  source = Fixture.sample(102400n)
  initial = Save.open(Encode.bytes(Utf8.encode(source)))
  do IO<Unit>:
    old : Editor.Session <- Session.loaded(Editor.load(initial))
    changed : Editor.Session <- Session.edits(20n, old)
    restored : Editor.Session = History.undo(20n, changed)
    +start : Nat <- IO.now()
    ticket : Chan(Release.Progress) <- IO.fork(Release.Progress,
      Release.drain_with_pause(65536n, 256n, pause, Release.begin(restored)))
    Native.main()
    +input_done : Nat <- IO.now()
    result : Release.Progress <- IO.join(Release.Progress, ticket)
    +end : Nat <- IO.now()
    Check.check(Heartbeat.complete(result))
    IO.print("native_release pause_ms=" ++ U32.show(pause) ++
      " input_ms=" ++ Nat.show(Nat.sub(input_done, start)) ++
      " remaining_ms=" ++ Nat.show(Nat.sub(end, input_done)) ++
      " total_ms=" ++ Nat.show(Nat.sub(end, start)))

def main() -> IO(Unit):
  run(1)
