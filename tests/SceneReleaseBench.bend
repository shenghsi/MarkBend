import Base
import ../src/SceneRelease.bend as Release
import ../src/DirectState.bend as Editor
import ./DocumentBench.bend as Fixture

def next(value: Release.Progress, more: Release.Queue -> IO(Unit), count: Nat,
  maximum: Nat, total: Nat) -> IO(Unit):
  match value:
    case Release.Complete{}:
      IO.print("scene_release slices=" ++ Nat.show(count) ++ " max_ms=" ++ Nat.show(maximum) ++
        " total_slice_ms=" ++ Nat.show(total))
    case Release.Pending{queue}:
      more(queue)

def run(fuel: Nat, queue: Release.Queue, +count: Nat, +maximum: Nat, +total: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit, 1, "Scene release did not complete")
    case 1n+remaining:
      do IO<Unit>:
        +start : Nat <- IO.now()
        result : Release.Progress = Release.step(32n, queue)
        +end : Nat <- IO.now()
        IO.sleep(1)
        next(result,
          q => run(remaining, q, 1n+count, Nat.max(maximum, Nat.sub(end, start)),
            Nat.add(total, Nat.sub(end, start))),
          1n+count, Nat.max(maximum, Nat.sub(end, start)), Nat.add(total, Nat.sub(end, start)))

def main() -> IO(Unit):
  session = Editor.start(Fixture.sample(102400n))
  run(32768n, Release.begin(session), 0n, 0n, 0n)
