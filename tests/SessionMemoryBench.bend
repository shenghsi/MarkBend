import Base
import ../src/DirectState.bend as State
import ./DirectCheck.bend as Check
import ./DocumentBench.bend as Fixture

def matching(same: Bool, next: Unit -> Maybe<&2, String>) -> Maybe<&2, String>:
  match same:
    case False{}:
      None{}
    case True{}:
      next(Unit{})

# Consume the reference prefix without constructing a second one-MiB string.
def remaining(expected: String, actual: String) -> Maybe<&2, String>:
  match expected actual:
    case SNil{} _:
      Some{actual}
    case SCon{a, rest_a} SCon{b, rest_b}:
      matching(Char.is_eq(a, b), unit => remaining(rest_a, rest_b))
    case _ _:
      None{}

def suffix_matches(result: Maybe<&2, String>, count: Nat) -> Bool:
  match result:
    case None{}:
      False{}
    case Some{suffix}:
      Check.source_equals(suffix, String.repeat("X", count))

def next_pattern(result: Maybe<&2, String>, next: String -> Maybe<&2, String>) -> Maybe<&2, String>:
  match result:
    case None{}:
      None{}
    case Some{rest}:
      next(rest)

# The fixture has 16,644 complete 63-character units and four final characters:
# 16,644 * 63 + 4 = 1,048,576. Check all of them before checking inserted text.
def pattern_remaining(fuel: Nat, actual: String, +unit: String) -> Maybe<&2, String>:
  match fuel:
    case 0n:
      remaining(String.take(unit, 4n), actual)
    case 1n+rest:
      next_pattern(remaining(unit, actual), tail => pattern_remaining(rest, tail, unit))

def selection_matches(snapshot: State.Snapshot, +position: Nat) -> Bool:
  match snapshot:
    case State.Snapshot{a, b, document}:
      Nat.is_eq(a, position) && Nat.is_eq(b, position)

def cursor(empty: Bool, length: Nat) -> Nat:
  match empty:
    case True{}:
      0n
    case False{}:
      length

def verified(+base: String, +snapshot: State.Snapshot, +count: Nat) -> Bool:
  +length = Nat.add(1048576n, count)
  +position = cursor(Nat.is_eq(count, 0n), length)
  suffix_matches(pattern_remaining(16644n, State.source(snapshot), base), count) &&
    selection_matches(snapshot, position) &&
    Nat.is_eq(State.source_length(snapshot), length)

def verify(+base: String, snapshot: State.Snapshot, +count: Nat, phase: String) -> IO(Unit):
  +length = Nat.add(1048576n, count)
  do IO<Unit>:
    Check.check(verified(base, snapshot, count))
    IO.print(phase ++ " count=" ++ Nat.show(count) ++ " scalars=" ++ Nat.show(length))

def edit_history(fuel: Nat, +base: String, +session: State.Session, count: Nat) -> IO(State.Session):
  match fuel:
    case 0n:
      IO.pure(State.Session, session)
    case 1n+rest:
      +next = State.edit(session, 10000000n, 10000000n, "X")
      +done = Nat.add(1n, count)
      do IO<State.Session>:
        verify(base, State.current(next), done, "edit")
        edit_history(rest, base, next, done)

def undo_history(fuel: Nat, +base: String, session: State.Session) -> IO(State.Session):
  match fuel:
    case 0n:
      IO.pure(State.Session, session)
    case 1n+ +rest:
      +next = State.undo(session)
      do IO<State.Session>:
        verify(base, State.current(next), rest, "undo")
        undo_history(rest, base, next)

def redo_history(fuel: Nat, +base: String, session: State.Session, count: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("Session history memory batch passed")
    case 1n+rest:
      +next = State.redo(session)
      +done = Nat.add(1n, count)
      do IO<Unit>:
        verify(base, State.current(next), done, "redo")
        redo_history(rest, base, next, done)

def after_undo(mode: String, +base: String, session: State.Session) -> IO(Unit):
  match mode:
    case "undo":
      IO.print("Session undo memory batch passed")
    case _:
      redo_history(20n, base, session, 0n)

def after_edit(mode: String, +base: String, session: State.Session) -> IO(Unit):
  match mode:
    case "edit":
      IO.print("Session edit memory batch passed")
    case _:
      do IO<Unit>:
        undone : State.Session <- undo_history(20n, base, session)
        after_undo(mode, base, undone)

def run(mode: String) -> IO(Unit):
  do IO<Unit>:
    Check.check(suffix_matches(remaining("ab", "abXX"), 2n))
    Check.check(Bool.not(suffix_matches(remaining("ab", "acXX"), 2n)))
    Check.check(Bool.not(suffix_matches(remaining("abc", "ab"), 0n)))
    Check.check(Bool.not(suffix_matches(remaining("ab", "abXXX"), 2n)))
    +base : String = "# Heading\n\nThis paragraph has **strong** text and *emphasis*.\n\n"
    edited : State.Session <- edit_history(20n, base, State.start(Fixture.sample(1048576n)), 0n)
    after_edit(mode, base, edited)

def choose(args: List<String>) -> IO(Unit):
  match args:
    case program <> mode <> Nil{}:
      run(mode)
    case _:
      run("all")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    choose(args)
