import Base
import ../src/DocumentOpen.bend as Open
import ../src/StoredEditor.bend as Stored
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ../src/DirectState.bend as Direct
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as Editor
import ./StoredTypingBench.bend as Typing
import ./DirectCheck.bend as Check
import ./SessionViewCheck.bend as View
import ../src/Document.bend as Document

def forced_view(value: Direct.View) -> IO(Unit):
  match value:
    case Direct.View{scene, visible}:
      do IO<Unit>:
        Check.check(Nat.is_gt(Document.count_scalars(visible, 0n), 0n))
        IO.print("Large indexed view constructed")

def indexed_view(session: Stored.Session) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      forced_view(Direct.view(editor))

def view_matches(session: Stored.Session) -> Bool:
  match session:
    case Stored.Session{editor, storage}:
      View.valid(editor)

def opened_count(session: Stored.Session) -> Bool:
  match session:
    case Stored.Session{editor, storage}:
      Nat.is_eq(Direct.source_length(Direct.current(editor)), 1048576n)

def check_view(enabled: Bool, +session: Stored.Session) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      do IO<Unit>:
        indexed_view(session)
        Check.check(view_matches(session))

def loaded(value: Open.Outcome, +source: String, +bytes: List<&2, U32>, +views: Bool) -> IO(Unit):
  match value:
    case Open.Opened{+session}:
      do IO<Unit>:
        Check.check(opened_count(session))
        IO.print("Large file opened with complete source count")
        Check.check(Editor.matches(session, source, Save.open(bytes)))
        IO.print("Large storage comparison passed")
        check_view(views, session)
        IO.print("Large file full source and storage comparison passed")
        +changed : Stored.Session <- Typing.accepted(Stored.edit(session, 0n, 0n, "新😀"))
        Check.check(Editor.matches(changed, "新😀" ++ source,
          Save.edit(Save.open(bytes), Encode.bytes(Utf8.encode("新😀" ++ source)))))
        check_view(views, changed)
        +restored : Stored.Session = Stored.undo(changed)
        Check.check(Editor.matches(restored, source, Save.open(bytes)))
        check_view(views, restored)
        Check.check(Editor.matches(Stored.redo(restored), "新😀" ++ source,
          Save.edit(Save.open(bytes), Encode.bytes(Utf8.encode("新😀" ++ source)))))
        check_view(views, Stored.redo(restored))
    case _:
      Check.check(False{})

def read_back(value: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  expected: List<&2, U32>) -> IO(Unit):
  match value:
    case (file, result):
      do IO<Unit>:
        File.close(file)
        actual : List<&2, U32> <- IO.pass(List<&2, U32>, result)
        Check.check(Save.bytes_equal(actual, expected))

def written(value: File & Result<&1, &1, U32 & String, Unit>, +path: String,
  +source: String, +bytes: List<&2, U32>, views: Bool) -> IO(Unit):
  match value:
    case (file, result):
      do IO<Unit>:
        File.close(file)
        IO.pass(Unit, result)
        IO.print("Large fixture file written")
        opened : Open.Outcome <- Open.read(path)
        loaded(opened, source, bytes, views)
        disk : File <- IO.try(File, File.open(path, "r"))
        actual : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(disk, 1048577)
        read_back(actual, bytes)
        IO.print("Real one-MiB file opening, Unicode edits, history, and unchanged disk check passed")

def run(views: Bool) -> IO(Unit):
  +source = Fixture.sample(1048576n)
  +bytes = Encode.bytes(Utf8.encode(source))
  do IO<Unit>:
    IO.print("Large fixture encoded")
    +path : String <- IO.try(String, IO.get_env("MARKBEND_OPEN_LARGE_PATH"))
    file : File <- IO.try(File, File.open(path, "w"))
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(file, bytes)
    written(result, path, source, bytes, views)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Large file fixture construction started")
    run(False{})
