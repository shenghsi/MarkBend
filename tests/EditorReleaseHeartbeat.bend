import Base
import ../src/EditorRelease.bend as Release
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./SessionDisposeBench.bend as Session
import ./StoredTypingBench.bend as History
import ./DirectCheck.bend as Check

def complete(value: Release.Progress) -> Bool:
  match value:
    case Release.Complete{}:
      True{}
    case _:
      False{}

def run(+pause: U32) -> IO(Unit):
  source = Fixture.sample(102400n)
  initial = Save.open(Encode.bytes(Utf8.encode(source)))
  do IO<Unit>:
    IO.print("Editor release fixture prepared")
    session : Editor.Session <- Session.loaded(Editor.load(initial))
    IO.print("Editor release session loaded")
    changed : Editor.Session <- Session.edits(20n, session)
    restored : Editor.Session = History.undo(20n, changed)
    IO.print("Editor release history prepared")
    +start : Nat <- IO.now()
    ticket : Chan(Release.Progress) <- IO.fork(Release.Progress,
      Release.drain_with_pause(65536n, 256n, pause, Release.begin(restored)))
    +queued : Nat <- IO.now()
    IO.sleep(10)
    +heartbeat : Nat <- IO.now()
    done : Release.Progress <- IO.join(Release.Progress, ticket)
    +end : Nat <- IO.now()
    Check.check(complete(done))
    IO.print("editor_release_heartbeat pause_ms=" ++ U32.show(pause) ++
      " dispatch_ms=" ++ Nat.show(Nat.sub(queued, start)) ++
      " heartbeat_ms=" ++ Nat.show(Nat.sub(heartbeat, queued)) ++
      " delay_ms=" ++ Nat.show(Nat.sub(Nat.sub(heartbeat, queued), 10n)) ++
      " completion_ms=" ++ Nat.show(Nat.sub(end, start)))

def main() -> IO(Unit):
  run(1)
