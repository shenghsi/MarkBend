import Base
import ../src/RecoveryEditor.bend as Bridge
import ../src/RecoveryPlan.bend as Plan
import ../src/RecoveryScan.bend as Scan
import ../src/RecoveryEntry.bend as Entry
import ../src/SaveState.bend as Save
import ../src/DirectState.bend as State
import ../src/LiveParagraph.bend as Live
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Fixture
import ./SaveStateCheck.bend as States
import ./Utf8Check.bend as Text
import ./NativeDirectCheck.bend as Driver
import ./DirectCheck.bend as Check

def original() -> String:
  "**ab** xyz"

def baseline() -> List<&2, U32>:
  [100, 105, 115, 107, 13, 10]

def recorded() -> Save.State:
  Save.State{Fixture.bytes(Utf8.encode(original())), baseline(), 1n,
    Some{Save.Ticket{0n, [112]}}}

def initial() -> Bridge.Outcome:
  Bridge.request(Bridge.open(Plan.prepare(Scan.Completed{
    Fixture.catalog(Entry.encode(Entry.Entry{[42], recorded()}))}, [42], baseline())))

def owned(catalog: Scan.Catalog, requested: List<&2, U32>) -> Bool:
  match catalog:
    case Scan.Catalog{Scan.Accepted{name, Entry.Entry{key, state}} <> Nil{}, Nil{}}:
      Save.bytes_equal(key, requested) && States.state_equal(state, recorded())
    case _:
      False{}

def checked(window: Window, +value: Bridge.Outcome,
  rest: Window -> Bridge.Outcome -> IO(Unit)) -> IO(Unit):
  match value:
    case Bridge.Opened{requested, catalog, save, +editor}:
      match save:
        case Save.State{current, saved, next, pending}:
          do IO<Unit>:
            Check.check(owned(catalog, requested))
            Check.check(States.state_equal(Save.State{current, saved, next, pending},
              Save.State{Fixture.bytes(Utf8.encode(State.source(State.current(editor)))),
                baseline(), 2n, Some{Save.Ticket{1n, Fixture.bytes(Utf8.encode(original()))}}}))
            verified : Window <- Driver.Driver.inspect_source(window, State.source(State.current(editor)))
            rest(verified, value)
    case _:
      do IO<Unit>:
        Live.LiveParagraph.close(window)
        Check.check(False{})

def step(window: Window, +value: Bridge.Outcome, action: U32,
  rest: Window -> Bridge.Outcome -> IO(Unit)) -> IO(Unit):
  match value:
    case Bridge.Opened{requested, catalog, save, editor}:
      do IO<Unit>:
        queued : Window <- Driver.Driver.enqueue(window, action)
        event : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
        Live.LiveParagraph.finish(event, editor,
          w => next => checked(w, Bridge.sync(value, next), rest))
    case _:
      do IO<Unit>:
        Live.LiveParagraph.close(window)
        Check.check(False{})

def inspect(window: Window, +value: Bridge.Outcome, source: String,
  visible: String, caret: U32, action: U32,
  rest: Window -> Bridge.Outcome -> IO(Unit)) -> IO(Unit):
  match value:
    case Bridge.Opened{requested, catalog, save, editor}:
      do IO<Unit>:
        Check.check(Text.text_equal(State.source(State.current(editor)), source, True{}))
        verified : Window <- Driver.Driver.inspect(window, visible, caret)
        step(verified, value, action, rest)
    case _:
      do IO<Unit>:
        Live.LiveParagraph.close(window)
        Check.check(False{})

def finish(window: Window, value: Bridge.Outcome) -> IO(Unit):
  match value:
    case Bridge.Opened{requested, catalog, save, editor}:
      do IO<Unit>:
        Check.check(Text.text_equal(State.source(State.current(editor)), "**中文** xyz", True{}))
        verified : Window <- Driver.Driver.inspect(window, "中文 xyz", 4)
        Live.LiveParagraph.close(verified)
        IO.print("Native recovery, input, composition, history, and save snapshots check passed")
    case _:
      do IO<Unit>:
        Live.LiveParagraph.close(window)
        Check.check(False{})

def after_composition(window: Window, value: Bridge.Outcome) -> IO(Unit):
  inspect(window, value, "**中文** x😀yz", "**中文** x😀yz", 4, 6, finish)

def after_active(window: Window, value: Bridge.Outcome) -> IO(Unit):
  inspect(window, value, "**ab** x😀yz", "**ab** x😀yz", 3, 5, after_composition)

def after_redo(window: Window, value: Bridge.Outcome) -> IO(Unit):
  inspect(window, value, "**ab** x😀yz", "ab x😀yz", 6, 4, after_active)

def after_undo(window: Window, value: Bridge.Outcome) -> IO(Unit):
  inspect(window, value, original(), "ab xyz", 4, 3, after_redo)

def after_edit(window: Window, value: Bridge.Outcome) -> IO(Unit):
  inspect(window, value, "**ab** x😀yz", "ab x😀yz", 6, 2, after_undo)

def after_select(window: Window, value: Bridge.Outcome) -> IO(Unit):
  inspect(window, value, original(), "ab xyz", 4, 1, after_edit)

def open(value: Bridge.Outcome) -> IO(Unit):
  match value:
    case Bridge.Opened{requested, catalog, save, +editor}:
      do IO<Unit>:
        opened : Window <- Live.LiveParagraph.open(State.source(State.current(editor)))
        shown : Window <- Live.LiveParagraph.present(opened, editor)
        # The host creates its text controls when next starts the event loop.
        step(shown, value, 0, after_select)
    case _:
      Check.check(False{})

def main() -> IO(Unit):
  open(initial())
