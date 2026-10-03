import Base
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as CheckEditor
import ./StoredTypingBench.bend as Typing
import ./DirectCheck.bend as Check

def loaded(value: Maybe<&2, Editor.Session>) -> IO(Editor.Session):
  match value:
    case Some{session}:
      IO.pure(Editor.Session, Editor.request(session))
    case None{}:
      IO.die(Editor.Session, 1, "Disposal benchmark load failed")

def edits(fuel: Nat, session: Editor.Session) -> IO(Editor.Session):
  match fuel:
    case 0n:
      IO.pure(Editor.Session, session)
    case 1n+rest:
      do IO<Editor.Session>:
        next : Editor.Session <- Typing.accepted(Editor.edit(session, 0n, 0n, "X"))
        edits(rest, next)

# Consume the final session reference. Do not retain it past the end timestamp.
def dispose(session: Editor.Session) -> Bool:
  True{}

def released(session: Editor.Session, mode: String) -> IO(Unit):
  do IO<Unit>:
    +start : Nat <- IO.now()
    done : Bool = dispose(session)
    +end : Nat <- IO.now()
    Check.check(done)
    IO.print("session_release mode=" ++ mode ++ " ms=" ++ Nat.show(Nat.sub(end, start)))

def cleared(session: Editor.Session, +source: String, +initial: Save.State) -> IO(Unit):
  do IO<Unit>:
    +start : Nat <- IO.now()
    +next : Editor.Session = Editor.clear_history(session)
    +end : Nat <- IO.now()
    Check.check(CheckEditor.matches(next, source, Save.request(initial)))
    Check.check(CheckEditor.matches(Editor.undo(next), source, Save.request(initial)))
    Check.check(CheckEditor.matches(Editor.redo(next), source, Save.request(initial)))
    IO.print("session_clear_history ms=" ++ Nat.show(Nat.sub(end, start)))

def sample(+source: String, +initial: Save.State) -> IO(Unit):
  do IO<Unit>:
    opened : Editor.Session <- loaded(Editor.load(initial))
    released(opened, "opened")
    base : Editor.Session <- loaded(Editor.load(initial))
    changed : Editor.Session <- edits(20n, base)
    released(changed, "20-edits")
    base : Editor.Session <- loaded(Editor.load(initial))
    changed : Editor.Session <- edits(20n, base)
    restored : Editor.Session = Typing.undo(20n, changed)
    released(restored, "20-undos")
    base : Editor.Session <- loaded(Editor.load(initial))
    changed : Editor.Session <- edits(20n, base)
    restored : Editor.Session = Typing.undo(20n, changed)
    cleared(restored, source, initial)

def main() -> IO(Unit):
  +source = Fixture.sample(1048576n)
  +initial = Save.open(Encode.bytes(Utf8.encode(source)))
  do IO<Unit>:
    sample(source, initial)
    IO.print("Persistent session disposal benchmark passed")
