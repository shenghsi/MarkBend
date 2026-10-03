import Base
import ../src/BlockScene.bend as Scene
import ../src/BlockIndex.bend as Index
import ./DocumentBench.bend as Fixture
import ./DirectCheck.bend as Check

def built(value: Scene.Scene) -> IO(Unit):
  match value:
    case Scene.Scene{runs, points}:
      do IO<Unit>:
        Check.check(Nat.is_gt(Index.list_count(Scene.Run, runs, 0n), 0n))
        Check.check(Nat.is_gt(Index.list_count(Nat, points, 0n), 0n))
        IO.print("One-MiB reference scene construction completed")

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("One-MiB reference scene construction started")
    built(Scene.build(Fixture.sample(1048576n), 0n, 0n))
