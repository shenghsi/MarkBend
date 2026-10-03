import Base
import ../src/WorkspaceLoop.bend as Loop
import ../src/LiveParagraph.bend as Live
import ../src/AppSaveAs.bend as As
import ../src/AppSave.bend as Save
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Stored
import ../src/SaveState.bend as Flat
import ../src/ByteBuffer.bend as Bytes
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as Storage
import ./ReturnCommandCheck.bend as Result
import ./AppSaveAsCheck.bend as Target
import ./DirectCheck.bend as Check

def checked(value: As.Workspace, +source: String, +caret: Nat) -> Bool:
  match value:
    case As.Uncertain{App.Document{App.Untitled{}, session}, As.Target{requested, path, key, parent}, id, snapshot}:
      String.eq(requested, "new.md") && String.eq(path, "/fixture/new.md") &&
        Flat.bytes_equal(key, [9]) && Flat.bytes_equal(parent, [8]) && Nat.is_eq(id, 0n) &&
        Flat.bytes_equal(Bytes.materialize(snapshot), Encode.bytes(Utf8.encode("- x"))) &&
        Result.verified(session, source, caret, caret,
          Flat.edit(Flat.request(Flat.open(Encode.bytes(Utf8.encode("- x")))), Encode.bytes(Utf8.encode(source))))
    case _:
      False{}

def after_redo(window: Window, workspace: As.Workspace) -> IO(Unit):
  do IO<Unit>:
    Check.check(checked(workspace, "- x\n- ", 6n))
    Live.LiveParagraph.close(window)
    IO.print("Workspace Return, undo, and redo retain uncertain target and captured snapshot")

def after_undo(window: Window, +workspace: As.Workspace) -> IO(Unit):
  do IO<Unit>:
    Check.check(checked(workspace, "- x", 3n))
    Loop.finish((window, Live.ParagraphRedo{}), workspace, after_redo)

def after_return(window: Window, +workspace: As.Workspace) -> IO(Unit):
  do IO<Unit>:
    Check.check(checked(workspace, "- x\n- ", 6n))
    Loop.finish((window, Live.ParagraphUndo{}), workspace, w => s => after_undo(w, s))

def main() -> IO(Unit):
  do IO<Unit>:
    +session : Stored.Session <- Storage.loaded(Stored.load(Flat.open(Encode.bytes(Utf8.encode("- x")))))
    workspace : As.Workspace = As.complete(As.start(As.Editing{App.with_session(App.Untitled{}, session)},
      As.Validated{Target.target()}), 0n, Save.Uncertain{})
    window : Window <- Live.LiveParagraph.open("- x")
    Live.LiveParagraph.continue_stored(window, session, w => s =>
      Loop.finish((w, Live.ParagraphReturn{3, 3}), workspace, w => s => after_return(w, s)))
