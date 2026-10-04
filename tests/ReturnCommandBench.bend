import Base
import ../src/ReturnCommand.bend as Return
import ../src/StoredEditor.bend as Stored
import ../src/DirectState.bend as Editor
import ../src/SceneIndex.bend as Scene
import ../src/StorageHistory.bend as History
import ../src/TextStorage.bend as Text
import ../src/ByteBuffer.bend as Bytes
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ../src/ScalarText.bend as Scalar
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as Storage
import ./ReturnCommandCheck.bend as Result
import ./DirectCheck.bend as Check

def appended_reference(prefix: String, suffix: String) -> String:
  Scalar.from_reversed(List.reverse(&2, Char, Scalar.to_chars(prefix)), suffix)

type AppendWork is Data:
  AppendWork{prefix: String, result: String}

def append_work(+prefix: String, suffix: String) -> AppendWork:
  AppendWork{prefix, appended_reference(prefix, suffix)}

def append_result(work: AppendWork) -> String:
  match work:
    case AppendWork{prefix, result}:
      result

def appended(prefix: String, suffix: String) -> String:
  append_result(append_work(prefix, suffix))

# These cached counts and dirty state are forced inside the timed interval.
# Complete byte, selection, baseline, view, and history checks run afterward.
def forced(+session: Stored.Session, +size: Nat, native: Nat) -> Bool:
  match session:
    case Stored.Session{+editor, History.Session{Text.Snapshot{bytes, map}, undo, redo, save, identity}}:
      Nat.is_eq(Editor.source_length(Editor.current(editor)), size) &&
        Nat.is_eq(Bytes.length(bytes), size) &&
        Nat.is_eq(Scene.native_length(Editor.index(editor)), native) && Stored.dirty(session)

def samples(fuel: Nat, +number: Nat, +session: Stored.Session, +position: Nat,
  +source: String, +expected: String, +size: Nat, +initial: Flat.State, +saved: Flat.State) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("Core Return command samples passed size=" ++ Nat.show(size))
    case 1n+rest:
      do IO<Unit>:
        +start : Nat <- IO.now()
        +next : Stored.Session <- Storage.accepted(Return.command(session, position, position))
        Check.check(forced(next, 3n+size, 3n+position))
        +stop : Nat <- IO.now()
        Check.check(Result.verified(next, expected, 3n+size, 3n+size, saved))
        Check.check(Result.verified(Stored.undo(next), source, size, size, initial))
        Check.check(Result.verified(Stored.redo(Stored.undo(next)), expected, 3n+size, 3n+size, saved))
        IO.print("core_return size=" ++ Nat.show(size) ++ " sample=" ++ Nat.show(number) ++
          " elapsed_ms=" ++ Nat.show(Nat.sub(stop, start)))
        samples(rest, 1n+number, session, position, source, expected, size, initial, saved)

def caret(snapshot: Editor.Snapshot, +size: Nat) -> Bool:
  match snapshot:
    case Editor.Snapshot{start, end, document}:
      Nat.is_eq(start, size) && Nat.is_eq(end, size)

def preflight(+session: Stored.Session, +size: Nat, native: Nat) -> Bool:
  match session:
    case Stored.Session{+editor, History.Session{Text.Snapshot{bytes, map}, undo, redo, save, identity}}:
      Nat.is_eq(Editor.source_length(Editor.current(editor)), size) &&
        Nat.is_eq(Bytes.length(bytes), size) &&
        Nat.is_eq(Scene.native_length(Editor.index(editor)), native) &&
        caret(Editor.current(editor), size) && Bool.not(Stored.dirty(session))

def chosen(+session: Stored.Session, source: String, expected: String, +size: Nat,
  initial: Flat.State, saved: Flat.State) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      +position = Scene.native_length(Editor.index(editor))
      do IO<Unit>:
        Check.check(preflight(session, size, position))
        IO.print("Core Return baseline preflight passed size=" ++ Nat.show(size))
        samples(20n, 1n, session, position, source, expected, size, initial, saved)

def ready(+session: Stored.Session, source: String, expected: String, +size: Nat,
  initial: Flat.State, saved: Flat.State) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      +position = Scene.to_native(Editor.index(editor), size)
      chosen(Stored.select(session, position, position), source, expected, size, initial, saved)

def benchmark_source(+source: String, +size: Nat) -> IO(Unit):
  +expected = appended(source, "\n- ")
  +initial = Flat.open(Encode.bytes(Utf8.encode(source)))
  +saved = Flat.edit(initial, Encode.bytes(Utf8.encode(expected)))
  do IO<Unit>:
    session : Stored.Session <- Storage.loaded(Stored.load(initial))
    ready(session, source, expected, size, initial, saved)

def benchmark(+size: Nat) -> IO(Unit):
  benchmark_source(appended(Fixture.sample(Nat.sub(size, 4n)), "\n- x"), size)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Core Return command; ASCII byte and scalar counts are equal; IO.now milliseconds")
    benchmark(102400n)
    benchmark(1048576n)
    benchmark_source("- " ++ Result.repeated(65536n, ""), 65538n)
