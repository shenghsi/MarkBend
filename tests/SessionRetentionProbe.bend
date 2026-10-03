import Base
import ../src/DirectState.bend as State
import ./DocumentBench.bend as Fixture

def fresh(session: State.Session) -> State.Session:
  match session:
    case State.Session{snapshot, undo, redo, view, cache, index}:
      State.create(snapshot, undo, redo)

def reset(cold: Bool, session: State.Session) -> State.Session:
  match cold:
    case True{}:
      fresh(session)
    case False{}:
      session

def edits(fuel: Nat, +session: State.Session, +cold: Bool, +base: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("Session retention probe passed base=" ++ Nat.show(String.length(base)))
    case 1n+rest:
      +next = reset(cold, State.edit(session, 10000000n, 10000000n, "X"))
      do IO<Unit>:
        IO.print(Nat.show(State.source_length(State.current(next))))
        edits(rest, next, cold, base)

def run(args: List<String>) -> IO(Unit):
  match args:
    case program <> "cold" <> Nil{}:
      edits(20n, State.start(Fixture.sample(1048576n)), True{}, "")
    case program <> "base" <> Nil{}:
      +base = Fixture.sample(1048576n)
      edits(20n, State.start(base), False{}, base)
    case _:
      edits(20n, State.start(Fixture.sample(1048576n)), False{}, "")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
