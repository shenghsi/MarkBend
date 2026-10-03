import Base
import ../src/LiveParagraph.bend as Live
import ../src/DirectState.bend as State
import ./DirectCheck.bend as Check
import ./DocumentBench.bend as Fixture
import ./FixtureCheck.bend as Reference

def NativeDocument.begin(measure: U32) -> IO(Unit):
  import "./native_document.c"

def NativeDocument.enqueue(window: Window, action: U32) -> IO(Window):
  import "./native_document.c"

def NativeDocument.configure(window: Window) -> IO(Window):
  import "./native_document.c"

def NativeDocument.presented(window: Window) -> IO(Window):
  import "./native_document.c"

def NativeDocument.frame(window: Window, phase: U32) -> IO(Window):
  import "./native_document.c"

def NativeDocument.scroll(window: Window) -> IO(Window):
  import "./native_document.c"

def check_open_event(event: Live.ParagraphEvent) -> IO(Unit):
  match event:
    case Live.ParagraphSelected{0, 0}:
      IO.pure(Unit, Unit{})
    case _:
      IO.die(Unit, 1, "Native document open event failed")

def check_edit(reference: Reference.Reference, count: Nat, window: Window, session: State.Session) -> IO(Window):
  do IO<Window>:
    drawn : Window <- NativeDocument.frame(window, 1)
    Check.check(Reference.snapshot_matches(State.current(session), reference, count))
    return drawn

def after_edit(fuel: Nat, +reference: Reference.Reference, +count: Nat,
  window: Window, +session: State.Session) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        drawn : Window <- check_edit(reference, count, window, session)
        scrolled : Window <- NativeDocument.scroll(drawn)
        Live.LiveParagraph.close(scrolled)
        IO.print("Native document benchmark passed")
    case 1n+rest:
      do IO<Unit>:
        drawn : Window <- check_edit(reference, count, window, session)
        queued : Window <- NativeDocument.enqueue(drawn, 1)
        edited : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
        Live.LiveParagraph.finish(edited, session,
          w => s => after_edit(rest, reference, 1n+count, w, s))

def opened(reference: Reference.Reference, +session: State.Session,
  update: Window & Live.ParagraphEvent) -> IO(Unit):
  (window, event) = update
  do IO<Unit>:
    check_open_event(event)
    drawn : Window <- NativeDocument.frame(window, 0)
    scrolled : Window <- NativeDocument.scroll(drawn)
    queued : Window <- NativeDocument.enqueue(scrolled, 1)
    edited : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish(edited, session, w => s => after_edit(19n, reference, 1n, w, s))

def run(+size: Nat, measure: U32) -> IO(Unit):
  do IO<Unit>:
    Reference.self_check()
    reference : Reference.Reference = Reference.create(size)
    +source : String = Fixture.sample(size)
    IO.print("Native document fixture: " ++ Nat.show(size) ++ " bytes")
    NativeDocument.begin(measure)
    +session : State.Session = State.start(source)
    window : Window <- Live.LiveParagraph.open(source)
    configured : Window <- NativeDocument.configure(window)
    shown : Window <- Live.LiveParagraph.present(configured, session)
    ready : Window <- NativeDocument.presented(shown)
    queued : Window <- NativeDocument.enqueue(ready, 0)
    event : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    opened(reference, session, event)

def choose(args: List<String>) -> IO(Unit):
  match args:
    case program <> "cold" <> Nil{}:
      run(102400n, 2)
    case program <> "cold-stages" <> Nil{}:
      run(102400n, 3)
    case program <> "large-cold" <> Nil{}:
      run(1048576n, 2)
    case program <> "large-cold-stages" <> Nil{}:
      run(1048576n, 3)
    case program <> "large" <> Nil{}:
      run(1048576n, 0)
    case program <> "large-stages" <> Nil{}:
      run(1048576n, 1)
    case program <> "stages" <> Nil{}:
      run(102400n, 1)
    case program <> Nil{}:
      run(102400n, 0)
    case _:
      IO.die(Unit, 2, "Use large, stages, large-stages, cold, cold-stages, large-cold, or large-cold-stages")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    choose(args)
