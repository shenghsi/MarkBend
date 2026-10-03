import Base
import ../src/StoredEditor.bend as Editor
import ../src/StorageHistory.bend as History
import ../src/PersistentSave.bend as Persistent
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Bytes
import ./StoredEditorCheck.bend as Correct
import ./DirectCheck.bend as Check

def dirty(session: Editor.Session) -> Bool:
  Editor.dirty(session)

def exact_dirty(session: Editor.Session) -> Bool:
  match session:
    case Editor.Session{editor, History.Session{current, undo, redo, save, identity}}:
      Persistent.dirty(save)

def undo(fuel: Nat, session: Editor.Session) -> Editor.Session:
  match fuel:
    case 0n:
      session
    case 1n+rest:
      undo(rest, Editor.undo(session))

def accepted(value: Editor.EditResult) -> IO(Editor.Session):
  match value:
    case Editor.Accepted{session}:
      IO.pure(Editor.Session, session)
    case _:
      IO.die(Editor.Session, 1, "Typing benchmark edit failed")

def run(fuel: Nat, +number: Nat, +session: Editor.Session,
  +source: String, +initial: Save.State) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        Check.check(Correct.matches(session, String.repeat("X", 20n) ++ source,
          Save.edit(Save.request(initial), Bytes.bytes(Utf8.encode(String.repeat("X", 20n) ++ source)))))
        +restored : Editor.Session <- IO.pure(Editor.Session, undo(20n, session))
        Check.check(Correct.matches(restored, source, Save.request(initial)))
        +start : Nat <- IO.now()
        clean : Bool = dirty(restored)
        +end : Nat <- IO.now()
        Check.check(Bool.not(clean))
        +exact_start : Nat <- IO.now()
        exact : Bool = exact_dirty(restored)
        +exact_end : Nat <- IO.now()
        Check.check(Bool.not(exact))
        # Retain the session across both timers. Dropping the final reference
        # can release all redo snapshots and must not enter comparison timing.
        Check.check(Correct.matches(restored, source, Save.request(initial)))
        IO.print("persistent_typing restored_dirty_ms=" ++ Nat.show(Nat.sub(end, start)))
        IO.print("persistent_typing restored_exact_ms=" ++ Nat.show(Nat.sub(exact_end, exact_start)))
        IO.print("One-MiB consecutive persistent typing benchmark passed")
    case 1n+rest:
      do IO<Unit>:
        +start : Nat <- IO.now()
        +next : Editor.Session <- accepted(Editor.edit(session, 0n, 0n, "X"))
        +edited : Nat <- IO.now()
        changed : Bool = dirty(next)
        +compared : Nat <- IO.now()
        Check.check(changed)
        IO.print("persistent_typing sample=" ++ Nat.show(number) ++
          " edit_ms=" ++ Nat.show(Nat.sub(edited, start)) ++
          " dirty_ms=" ++ Nat.show(Nat.sub(compared, edited)))
        run(rest, 1n+number, next, source, initial)

def opened(value: Maybe<&2, Editor.Session>, source: String, initial: Save.State) -> IO(Unit):
  match value:
    case Some{session}:
      run(20n, 1n, Editor.request(session), source, initial)
    case None{}:
      IO.die(Unit, 1, "Typing benchmark load failed")

def main() -> IO(Unit):
  +source = Fixture.sample(1048576n)
  +initial = Save.open(Bytes.bytes(Utf8.encode(source)))
  opened(Editor.load(initial), source, initial)
