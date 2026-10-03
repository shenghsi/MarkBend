import Base
import ../src/ResolvedOpen.bend as Open
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Stored
import ../src/DirectState.bend as Editor
import ../src/PersistentSave.bend as Save
import ../src/StorageHistory.bend as History
import ../src/SaveState.bend as Flat
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check
import ./Utf8Check.bend as Text

def rejected(value: Open.Outcome, expected: Open.Reason) -> Bool:
  match value expected:
    case Open.Rejected{raw, Open.InvalidPath{}} Open.InvalidPath{}:
      True{}
    case Open.Rejected{raw, Open.InvalidIdentity{}} Open.InvalidIdentity{}:
      True{}
    case Open.Rejected{raw, Open.InvalidUtf8{}} Open.InvalidUtf8{}:
      True{}
    case _ _:
      False{}

def opened(value: Open.Outcome) -> Bool:
  match value:
    case Open.Opened{App.Document{App.Resolved{requested, path, identity},
      Stored.Session{editor, History.Session{current, undo, redo, save, identity_tag}}}}:
      Text.text_equal(requested, "alias.md", True{}) &&
        Text.text_equal(path, "/file", True{}) &&
        Flat.bytes_equal(identity, [1, 2]) &&
        Text.text_equal(Editor.source(Editor.current(editor)), "a\r\n\0", True{}) &&
        States.state_equal(Save.materialize(save), Flat.open([97, 13, 10, 0]))
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Check.check(opened(Open.decode(Open.Raw{"alias.md", [47, 102, 105, 108, 101], [1, 2], [97, 13, 10, 0]})))
    Check.check(rejected(Open.decode(Open.Raw{"alias.md", [255], [1], [97]}), Open.InvalidPath{}))
    Check.check(rejected(Open.decode(Open.Raw{"alias.md", Nil{}, [1], [97]}), Open.InvalidPath{}))
    Check.check(rejected(Open.decode(Open.Raw{"alias.md", [47, 0], [1], [97]}), Open.InvalidPath{}))
    Check.check(rejected(Open.decode(Open.Raw{"alias.md", [47], Nil{}, [97]}), Open.InvalidIdentity{}))
    Check.check(rejected(Open.decode(Open.Raw{"alias.md", [47], [256], [97]}), Open.InvalidIdentity{}))
    Check.check(rejected(Open.decode(Open.Raw{"alias.md", [47], [1], [255]}), Open.InvalidUtf8{}))
    IO.print("Resolved document strict path, identity, and source checks passed")
