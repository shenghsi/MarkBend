import Base
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Bytes
import ./StoredEditorCheck.bend as CheckEditor
import ./DirectCheck.bend as Check

def checked(value: Editor.EditResult, source: String, expected: Save.State) -> Bool:
  match value:
    case Editor.Accepted{session}:
      CheckEditor.matches(session, source, expected)
    case _:
      False{}

def sample(+session: Editor.Session, number: Nat, source: String,
  expected: Save.State) -> IO(Unit):
  do IO<Unit>:
    +start : Nat <- IO.now()
    result : Editor.EditResult = Editor.edit(session, 0n, 0n, "X")
    +end : Nat <- IO.now()
    Check.check(checked(result, source, expected))
    IO.print("persistent_edit sample=" ++ Nat.show(number) ++
      " total_ms=" ++ Nat.show(Nat.sub(end, start)))

def repeat(fuel: Nat, +session: Editor.Session, +number: Nat,
  +source: String, +expected: Save.State) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("One-MiB persistent formatted editor benchmark passed")
    case 1n+rest:
      do IO<Unit>:
        sample(session, number, source, expected)
        repeat(rest, session, 1n+number, source, expected)

def opened(value: Maybe<&2, Editor.Session>, source: String, expected: Save.State) -> IO(Unit):
  match value:
    case Some{session}:
      repeat(20n, Editor.request(session), 1n, source, expected)
    case None{}:
      IO.die(Unit, 1, "Persistent editor benchmark load failed")

def main() -> IO(Unit):
  +source = Fixture.sample(1048576n)
  +initial = Save.open(Bytes.bytes(Utf8.encode(source)))
  opened(Editor.load(initial), "X" ++ source,
    Save.edit(Save.request(initial), Bytes.bytes(Utf8.encode("X" ++ source))))
