import Base
import ../src/Projection.bend as Projection
import ../src/DirectState.bend as State
import ../src/Experiment.bend as E
import ../src/Document.bend as D

def check(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "Direct editing check failed")

# Compare every character without rebuilding the input strings. Base String.eq
# returns through String.cmp, which reconstructs both strings before dropping them.
def source_equals_next(same: Bool, next: Unit -> Bool) -> Bool:
  match same:
    case False{}:
      False{}
    case True{}:
      next(Unit{})

def source_equals(actual: String, expected: String) -> Bool:
  match actual expected:
    case SNil{} SNil{}:
      True{}
    case SCon{a, rest_a} SCon{b, rest_b}:
      source_equals_next(Char.is_eq(a, b), unit => source_equals(rest_a, rest_b))
    case _ _:
      False{}

def snapshot_is(snapshot: State.Snapshot, source: String, start: Nat, end: Nat) -> Bool:
  match snapshot:
    case State.Snapshot{a, b, D.Document{blocks, next, reparsed}}:
      source_equals(D.source(blocks), source) &&
        Nat.is_eq(a, start) && Nat.is_eq(b, end)

def main() -> IO(Unit):
  +initial = State.start("**ab** and *cd*")
  +selected = State.select(initial, 12n, 12n)
  +edited = State.edit(selected, 9n, 10n, "X")
  +reverted = State.undo(edited)
  do IO<Unit>:
    check(source_equals("中文😀\r\n", "中文😀\r\n"))
    check(Bool.not(source_equals("abc", "abd")))
    check(Bool.not(source_equals("abc", "ab")))
    check(Bool.not(source_equals("ab", "abc")))
    check(String.eq(Projection.text(Projection.runs("**ab** and *cd*", 0n, 0n)), "**ab** and cd"))
    check(snapshot_is(State.current(selected), "**ab** and *cd*", 13n, 13n))
    check(String.eq(Projection.text(Projection.runs("**ab** and *cd*", 13n, 13n)), "ab and *cd*"))
    check(snapshot_is(State.current(edited), "**ab** and *cX*", 14n, 14n))
    check(snapshot_is(State.current(reverted), "**ab** and *cd*", 13n, 13n))
    check(snapshot_is(State.current(State.redo(reverted)), "**ab** and *cX*", 14n, 14n))
    check(snapshot_is(State.current(State.edit(State.start("中文😀"), 2n, 4n, "日\n")), "中文日\n", 4n, 4n))
    check(snapshot_is(State.current(State.edit(State.start(""), 0n, 0n, "😀")), "😀", 1n, 1n))
    check(snapshot_is(State.current(State.edit(State.start("\\*a"), 2n, 3n, "b")), "\\*b", 3n, 3n))
    check(snapshot_is(State.current(State.edit(State.start("abc"), 3n, 1n, "X")), "aX", 2n, 2n))
    check(snapshot_is(State.current(State.undo(State.start("abc"))), "abc", 0n, 0n))
    check(snapshot_is(State.current(State.redo(State.start("abc"))), "abc", 0n, 0n))
    IO.print("Direct editing batch passed")
