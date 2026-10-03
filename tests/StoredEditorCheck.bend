import Base
import ../src/StoredEditor.bend as Stored
import ../src/DirectState.bend as Editor
import ../src/StorageHistory.bend as History
import ../src/PersistentSave.bend as Save
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./TextStorageCheck.bend as Text
import ./SaveStateCheck.bend as States
import ./Utf8Check.bend as Strings
import ./DirectCheck.bend as Check

def loaded(value: Maybe<&2, Stored.Session>) -> IO(Stored.Session):
  match value:
    case Some{session}:
      IO.pure(Stored.Session, session)
    case None{}:
      IO.die(Stored.Session, 1, "Stored editor load failed")

def accepted(value: Stored.EditResult) -> IO(Stored.Session):
  match value:
    case Stored.Accepted{session}:
      IO.pure(Stored.Session, session)
    case _:
      IO.die(Stored.Session, 1, "Stored editor edit failed")

def matches(session: Stored.Session, +source: String, expected: Flat.State) -> Bool:
  match session:
    case Stored.Session{editor, History.Session{current, undo, redo, save, identity}}:
      Text.matches(current, source) &&
        Strings.text_equal(Editor.source(Editor.current(editor)), source, True{}) &&
        States.state_equal(Save.materialize(save), expected)

def rejected_source_edit(value: Stored.EditResult, +source: String, +initial: Flat.State) -> Bool:
  match value:
    case Stored.Rejected{+retained}:
      matches(retained, "**ab**Z 中文😀\r\n",
        Flat.edit(initial, Encode.bytes(Utf8.encode("**ab**Z 中文😀\r\n")))) &&
        matches(Stored.undo(retained), source, initial)
    case _:
      False{}

def main() -> IO(Unit):
  +source : String = "**ab** 中文😀\r\n"
  +initial = Flat.open(Encode.bytes(Utf8.encode(source)))
  do IO<Unit>:
    +opened : Stored.Session <- loaded(Stored.load(initial))
    +source_edit : Stored.Session <- accepted(Stored.edit_source(opened, 6n, 6n, "Z"))
    IO.print("Source-range edit accepted")
    Check.check(matches(source_edit, "**ab**Z 中文😀\r\n",
      Flat.edit(initial, Encode.bytes(Utf8.encode("**ab**Z 中文😀\r\n")))))
    Check.check(matches(Stored.undo(source_edit), source, initial))
    Check.check(matches(Stored.redo(Stored.undo(source_edit)), "**ab**Z 中文😀\r\n",
      Flat.edit(initial, Encode.bytes(Utf8.encode("**ab**Z 中文😀\r\n")))))
    IO.print("Source-range bytes and history passed")
    Check.check(rejected_source_edit(Stored.edit_source(source_edit, 4096n, 4096n, "bad"), source, initial))
    +first : Stored.Session <- accepted(Stored.edit(opened, 0n, 0n, "X"))
    +saving : Stored.Session <- IO.pure(Stored.Session, Stored.request(first))
    +second : Stored.Session <- accepted(Stored.edit(saving, 1n, 1n, "中😀"))
    +replacement : Stored.Session <- accepted(Stored.replace_source(second, "# 新😀\r\n\0"))
    +empty : Stored.Session <- accepted(Stored.replace_source(Stored.undo(replacement), ""))
    Check.check(matches(first, "X" ++ source, Flat.edit(initial, Encode.bytes(Utf8.encode("X" ++ source)))))
    Check.check(matches(Stored.undo(first), source, initial))
    Check.check(matches(Stored.redo(Stored.undo(first)), "X" ++ source,
      Flat.edit(initial, Encode.bytes(Utf8.encode("X" ++ source)))))
    +expected : Flat.State <- IO.pure(Flat.State,
      Flat.request(Flat.edit(initial, Encode.bytes(Utf8.encode("X" ++ source)))))
    Check.check(matches(second, "X中😀" ++ source,
      Flat.edit(expected, Encode.bytes(Utf8.encode("X中😀" ++ source)))))
    Check.check(matches(replacement, "# 新😀\r\n\0",
      Flat.edit(expected, Encode.bytes(Utf8.encode("# 新😀\r\n\0")))))
    Check.check(matches(Stored.undo(replacement), "X中😀" ++ source,
      Flat.edit(expected, Encode.bytes(Utf8.encode("X中😀" ++ source)))))
    Check.check(matches(Stored.redo(Stored.undo(replacement)), "# 新😀\r\n\0",
      Flat.edit(expected, Encode.bytes(Utf8.encode("# 新😀\r\n\0")))))
    Check.check(matches(Stored.redo(empty), "", Flat.edit(expected, [])))
    Check.check(matches(Stored.redo(Stored.undo(second)), "X中😀" ++ source,
      Flat.edit(expected, Encode.bytes(Utf8.encode("X中😀" ++ source)))))
    Check.check(matches(Stored.undo(second), "X" ++ source, expected))
    Check.check(matches(Stored.undo(Stored.complete(second, 0n, Flat.Confirmed{})), "X" ++ source,
      Flat.complete(expected, 0n, Flat.Confirmed{})))
    Check.check(matches(opened, source, initial))
    Check.check(matches(Stored.undo(Stored.clear_history(second)), "X中😀" ++ source,
      Flat.edit(expected, Encode.bytes(Utf8.encode("X中😀" ++ source)))))
    Check.check(matches(Stored.redo(Stored.clear_history(Stored.undo(second))), "X" ++ source, expected))
    IO.print("Formatted editor and persistent storage connection check passed")
