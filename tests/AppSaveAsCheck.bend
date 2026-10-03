import Base
import ../src/AppSaveAs.bend as As
import ../src/AppSave.bend as Save
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Flat
import ../src/ByteBuffer.bend as Bytes
import ../src/StorageHistory.bend as History
import ../src/PersistentSave.bend as Persistent
import ../src/Utf8.bend as Utf8
import ./AppInputCheck.bend as Model
import ./StoredEditorCheck.bend as Stored
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def target() -> As.Target:
  As.Target{"new.md", "/fixture/new.md", [9], [8]}

def dirty() -> Flat.State:
  Flat.edit(Flat.open([65]), Encode.bytes(Utf8.encode(Model.text())))

def waiting(value: As.Workspace, state: Flat.State) -> Bool:
  match value:
    case As.Saving{document, As.Target{requested, path, key, parent}, id, snapshot}:
      Model.same(document, Model.text(), state) && String.eq(requested, "new.md") &&
        String.eq(path, "/fixture/new.md") && Flat.bytes_equal(key, [9]) &&
        Flat.bytes_equal(parent, [8]) && Nat.is_eq(id, 0n) &&
        Flat.bytes_equal(Bytes.materialize(snapshot), Encode.bytes(Utf8.encode(Model.text())))
    case _:
      False{}

def old(value: As.Workspace, state: Flat.State) -> Bool:
  match value:
    case As.Editing{document}:
      Model.same(document, Model.text(), state)
    case _:
      False{}

def adopted(value: As.Workspace, source: String, state: Flat.State) -> Bool:
  match value:
    case As.Editing{App.Document{App.Resolved{requested, path, key}, session}}:
      String.eq(requested, "new.md") && String.eq(path, "/fixture/new.md") &&
        Flat.bytes_equal(key, [9]) && Stored.matches(session, source, state)
    case _:
      False{}

def uncertain(value: As.Workspace, state: Flat.State) -> Bool:
  match value:
    case As.Uncertain{document, target, id, snapshot}:
      waiting(As.Saving{document, target, id, snapshot}, state)
    case _:
      False{}

def untitled(value: As.Workspace, state: Flat.State) -> Bool:
  match value:
    case As.Editing{App.Document{App.Untitled{}, session}}:
      Stored.matches(session, Model.text(), state)
    case _:
      False{}

def wrong_snapshot(value: As.Workspace) -> As.Workspace:
  match value:
    case As.Saving{App.Document{destination, Editor.Session{editor,
      History.Session{current, undo, redo, Persistent.State{bytes, +baseline, next, pending}, identity}}}, target, id, snapshot}:
      As.Saving{App.with_session(destination, Editor.Session{editor,
        History.Session{current, undo, redo, Persistent.State{bytes, baseline, next, pending}, identity}}), target, id, baseline}
    case value:
      value

def wrong_retained(value: As.Workspace, state: Flat.State) -> Bool:
  match value:
    case As.Saving{document, As.Target{requested, path, key, parent}, id, snapshot}:
      Model.same(document, Model.text(), state) && String.eq(requested, "new.md") &&
        String.eq(path, "/fixture/new.md") && Flat.bytes_equal(key, [9]) &&
        Flat.bytes_equal(parent, [8]) && Nat.is_eq(id, 0n) &&
        Flat.bytes_equal(Bytes.materialize(snapshot), [65])
    case _:
      False{}

def main() -> IO(Unit):
  +pending = Flat.request(dirty())
  do IO<Unit>:
    initial : Editor.Session <- Stored.loaded(Editor.load(Flat.open([65])))
    +edited : Editor.Session <- Stored.accepted(Editor.replace_source(initial, Model.text()))
    +idle : As.Workspace = As.Editing{Model.document(edited)}
    +active : As.Workspace = As.start(idle, As.Validated{target()})
    Check.check(old(As.start(idle, As.Cancelled{}), dirty()))
    Check.check(old(As.start(idle, As.Unavailable{}), dirty()))
    Check.check(old(As.start(idle, As.Validated{As.Target{"new.md", "bad\0path", [9], [8]}}), dirty()))
    Check.check(old(As.start(idle, As.Validated{As.Target{"new.md", "/fixture/new.md", [256], [8]}}), dirty()))
    Check.check(waiting(active, pending))
    Check.check(waiting(As.start(active, As.Validated{target()}), pending))
    Check.check(waiting(As.complete(active, 1n, Save.Confirmed{}), pending))
    Check.check(wrong_retained(As.complete(wrong_snapshot(active), 0n, Save.Confirmed{}), pending))
    Check.check(old(As.complete(active, 0n, Save.Conflict{}), Flat.complete(pending, 0n, Flat.OldKept{})))
    Check.check(adopted(As.complete(active, 0n, Save.Confirmed{}), Model.text(), Flat.complete(pending, 0n, Flat.Confirmed{})))
    +blocked : As.Workspace = As.complete(active, 0n, Save.Uncertain{})
    Check.check(uncertain(blocked, pending))
    Check.check(uncertain(As.complete(blocked, 0n, Save.Confirmed{}), pending))
    Check.check(uncertain(As.start(blocked, As.Validated{target()}), pending))
    Check.check(uncertain(As.select(blocked, 0n, 0n), pending))
    Check.check(uncertain(As.undo(As.edit(blocked, 0n, 0n, "X")), pending))
    +new_document : As.Workspace = As.Editing{App.with_session(App.Untitled{}, edited)}
    Check.check(untitled(As.start(new_document, As.Cancelled{}), dirty()))
    Check.check(adopted(As.complete(As.start(new_document, As.Validated{target()}), 0n, Save.Confirmed{}),
      Model.text(), Flat.complete(pending, 0n, Flat.Confirmed{})))
    +later : As.Workspace = As.replace_source(active, "later😀")
    +finished : As.Workspace = As.complete(later, 0n, Save.Confirmed{})
    Check.check(adopted(finished, "later😀",
      Flat.complete(Flat.edit(pending, Encode.bytes(Utf8.encode("later😀"))), 0n, Flat.Confirmed{})))
    Check.check(adopted(As.undo(finished), Model.text(), Flat.complete(pending, 0n, Flat.Confirmed{})))
    Check.check(adopted(As.redo(As.undo(finished)), "later😀",
      Flat.complete(Flat.edit(pending, Encode.bytes(Utf8.encode("later😀"))), 0n, Flat.Confirmed{})))
    Check.check(adopted(As.complete(finished, 0n, Save.Confirmed{}), "later😀",
      Flat.complete(Flat.edit(pending, Encode.bytes(Utf8.encode("later😀"))), 0n, Flat.Confirmed{})))
    IO.print("Save As transaction cancellation, target adoption, stale results, and uncertainty passed")
