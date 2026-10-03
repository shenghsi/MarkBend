import Base
import ../src/ReturnCommand.bend as Return
import ../src/ListReturn.bend as Legacy
import ../src/DirectState.bend as State
import ../src/TextPosition.bend as Position
import ../src/Document.bend as D
import ../src/SceneIndex.bend as Index
import ./ReturnPreparedCheck.bend as Prepared
import ./IndexedReturnCheck.bend as Plan
import ./SessionViewCheck.bend as View
import ./DirectCheck.bend as Check

def undo_matches(snapshot: State.Snapshot, source: String, selected: State.Snapshot) -> Bool:
  match selected:
    case State.Snapshot{start, end, document}:
      Check.snapshot_is(snapshot, source, start, end)

def verified(prepared: Return.DirectPrepared, +original: State.Session,
  start: Nat, end: Nat) -> Bool:
  match prepared:
    case Return.DirectPrepared{+edit, +session}:
      match edit:
        case Legacy.Edit{+first, last, +text}:
          +source = State.source(State.current(original))
          +expected = Position.replace(source, first, last, text)
          +caret = Nat.add(first, D.count_scalars(text, 0n))
          +selected = State.current(State.select(original, start, end))
          Plan.same(edit, Prepared.selected_plan(selected)) &&
            Prepared.replayed(original, session) && View.valid(session) &&
            Check.snapshot_is(State.current(session), expected, caret, caret) &&
            undo_matches(State.current(State.undo(session)), source, selected) &&
            View.valid(State.undo(session)) &&
            Check.snapshot_is(State.current(State.redo(State.undo(session))), expected, caret, caret)

def ends(fuel: Nat, +session: State.Session, +start: Nat, +end: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        Check.check(verified(Return.prepare_direct(session, start, end), session, start, end))
        ends(rest, session, start, 1n+end)

def starts(fuel: Nat, +session: State.Session, +size: Nat, +start: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        ends(1n+size, session, start, 0n)
        starts(rest, session, size, 1n+start)

def fixture(source: String) -> IO(Unit):
  +session = State.start(source)
  +size = Index.native_length(State.index(session))
  starts(1n+size, session, size, 0n)

def main() -> IO(Unit):
  do IO<Unit>:
    fixture("")
    fixture("- x")
    fixture("* **ab**")
    fixture("**ab**\n- x")
    fixture("- \t\r\n")
    fixture("# h\n\n- 中😀")
    fixture("```\n- x\n```\n")
    IO.print("Direct prepared Return exact source, patch replay, views, and history passed for all selection pairs")
