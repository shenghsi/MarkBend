import Base
import ../src/EditorRelease.bend as Release
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./SessionDisposeBench.bend as Session
import ./StoredTypingBench.bend as History

def next(value: Release.Progress, more: Release.Queue -> IO(Unit), budget: Nat,
  count: Nat, maximum: Nat, total: Nat, elapsed: Nat) -> IO(Unit):
  match value:
    case Release.Complete{}:
      IO.print("editor_release budget=" ++ Nat.show(budget) ++ " slices=" ++ Nat.show(count) ++
        " max_ms=" ++ Nat.show(maximum) ++ " total_slice_ms=" ++ Nat.show(total) ++
        " elapsed_ms=" ++ Nat.show(elapsed))
    case Release.Pending{queue}:
      more(queue)

def run(fuel: Nat, +budget: Nat, queue: Release.Queue, +count: Nat,
  +maximum: Nat, +total: Nat, +started: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit, 1, "Complete editor release did not complete")
    case 1n+remaining:
      do IO<Unit>:
        +start : Nat <- IO.now()
        result : Release.Progress = Release.step(budget, queue)
        +end : Nat <- IO.now()
        IO.sleep(1)
        +now : Nat <- IO.now()
        next(result,
          q => run(remaining, budget, q, 1n+count, Nat.max(maximum, Nat.sub(end, start)),
            Nat.add(total, Nat.sub(end, start)), started),
          budget, 1n+count, Nat.max(maximum, Nat.sub(end, start)),
          Nat.add(total, Nat.sub(end, start)), Nat.sub(now, started))

def sample(+budget: Nat, size: Nat) -> IO(Unit):
  source = Fixture.sample(size)
  initial = Save.open(Encode.bytes(Utf8.encode(source)))
  do IO<Unit>:
    session : Editor.Session <- Session.loaded(Editor.load(initial))
    changed : Editor.Session <- Session.edits(20n, session)
    restored : Editor.Session = History.undo(20n, changed)
    +started : Nat <- IO.now()
    run(65536n, budget, Release.begin(restored), 0n, 0n, 0n, started)

def main() -> IO(Unit):
  do IO<Unit>:
    sample(256n, 102400n)
    sample(1024n, 102400n)
