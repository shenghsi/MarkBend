import Base
import ../src/LiveParagraph.bend as Live
import ../src/StoredEditor.bend as Stored
import ../src/DirectState.bend as State
import ../src/SceneIndex.bend as Scene
import ../src/StorageHistory.bend as History
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as Storage
import ./ReturnCommandCheck.bend as Result
import ./ReturnCommandBench.bend as Core
import ./DocumentBench.bend as Fixture
import ./DirectCheck.bend as Check
import ../src/BlockScene.bend as FullScene
import ./NativeReturnPatchCheck.bend as Reference

# Compare the long-item result with an independent complete attributed render.
# This check runs after the frame clock has stopped.
def reference_long(window: Window, +source: String, +position: Nat, long: Bool) -> IO(Window):
  match long:
    case True{}:
      Reference.expected(window, FullScene.build(source, position, position))
    case False{}:
      IO.pure(Window, window)

def ReturnBench.prepare(window: Window, stages: U32) -> IO(Window):
  import "./native_return_bench.c"

def ReturnBench.initialize(window: Window) -> IO(Window):
  import "./native_return_bench.c"

def ReturnBench.enqueue(window: Window) -> IO(Window):
  import "./native_return_bench.c"

def ReturnBench.frame(window: Window) -> IO(Window):
  import "./native_return_bench.c"

def ReturnBench.inspect(window: Window, source: String) -> IO(Window):
  import "./native_return_bench.c"

def ReturnBench.done(window: Window) -> IO(Window):
  import "./native_return_bench.c"

def returned(event: Live.ParagraphEvent) -> Bool:
  match event:
    case Live.ParagraphReturn{start, end}:
      U32.is_eq(start, end)
    case _:
      False{}

def checked_event(update: Window & Live.ParagraphEvent,
  next: Window & Live.ParagraphEvent -> IO(Unit)) -> IO(Unit):
  match update:
    case (window, +event):
      do IO<Unit>:
        Check.check(returned(event))
        next((window, event))

def empty_history(session: Stored.Session) -> Bool:
  match session:
    case Stored.Session{State.Session{current, Nil{}, Nil{}, view, cache, index},
      History.Session{snapshot, Nil{}, Nil{}, save, identity}}:
      True{}
    case _:
      False{}

def no_redo(session: Stored.Session) -> Bool:
  match session:
    case Stored.Session{State.Session{current, undo, Nil{}, view, cache, index},
      History.Session{snapshot, history, Nil{}, save, identity}}:
      True{}
    case _:
      False{}

def samples(fuel: Nat, +source: String, +expected: String, +size: Nat,
  +initial: Flat.State, +saved: Flat.State, +stages: U32,
  window: Window, +baseline: Stored.Session) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        checked : Window <- ReturnBench.done(window)
        Live.LiveParagraph.close(checked)
        IO.print("Native Return layout and display samples passed")
    case 1n+rest:
      do IO<Unit>:
        Check.check(Result.verified(baseline, source, size, size, initial))
        inspected : Window <- ReturnBench.inspect(window, source)
        ready : Window <- ReturnBench.prepare(inspected, stages)
        queued : Window <- ReturnBench.enqueue(ready)
        event : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
        checked_event(event, update => Live.LiveParagraph.finish_stored(update, baseline,
          w => +s => do IO<Unit>:
            drawn : Window <- ReturnBench.frame(w)
            Check.check(no_redo(s))
            Check.check(Result.verified(s, expected, 3n+size, 3n+size, saved))
            exact : Window <- ReturnBench.inspect(drawn, expected)
            reference : Window <- reference_long(exact, expected, 3n+size, Nat.is_eq(size, 65538n))
            +undone : Stored.Session = Stored.undo(s)
            Check.check(Result.verified(undone, source, size, size, initial))
            Check.check(Result.verified(Stored.redo(undone), expected, 3n+size, 3n+size, saved))
            Live.LiveParagraph.continue_stored(reference, undone,
              next => history => samples(rest, source, expected, size, initial, saved,
                stages, next, history))))

def selected(+session: Stored.Session, +source: String, +size: Nat,
  +stages: U32, +initial: Flat.State) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      +expected = Core.appended(source, "\n- ")
      +saved = Flat.edit(initial, Encode.bytes(Utf8.encode(expected)))
      +position = Scene.to_native(State.index(editor), size)
      do IO<Unit>:
        window : Window <- Live.LiveParagraph.open(source)
        IO.print("Native Return fixture bytes=" ++ Nat.show(size) ++ " stages=" ++ U32.show(stages))
        Live.LiveParagraph.continue_stored(window, Stored.select(session, position, position),
          w => s => do IO<Unit>:
            queued : Window <- ReturnBench.initialize(w)
            event : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
            Live.LiveParagraph.finish_stored(event, s,
              ready => +history => do IO<Unit>:
                Check.check(empty_history(history))
                samples(20n, source, expected, size, initial, saved,
                  stages, ready, history)))

def run(+source: String, stages: U32) -> IO(Unit):
  +size = String.length(source)
  +initial = Flat.open(Encode.bytes(Utf8.encode(source)))
  do IO<Unit>:
    session : Stored.Session <- Storage.loaded(Stored.load(initial))
    selected(session, source, size, stages, initial)

def choose(args: List<String>) -> IO(Unit):
  match args:
    case program <> "small" <> "stages" <> Nil{}:
      run(Core.appended(Fixture.sample(102396n), "\n- x"), 1)
    case program <> "large" <> "stages" <> Nil{}:
      run(Core.appended(Fixture.sample(1048572n), "\n- x"), 1)
    case program <> "long" <> "stages" <> Nil{}:
      run("- " ++ Result.repeated(65536n, ""), 1)
    case program <> "small" <> Nil{}:
      run(Core.appended(Fixture.sample(102396n), "\n- x"), 0)
    case program <> "large" <> Nil{}:
      run(Core.appended(Fixture.sample(1048572n), "\n- x"), 0)
    case program <> "long" <> Nil{}:
      run("- " ++ Result.repeated(65536n, ""), 0)
    case _:
      IO.die(Unit, 1, "Use small, large, or long, with optional stages")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    choose(args)
