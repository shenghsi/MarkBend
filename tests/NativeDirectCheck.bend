import Base
import ../src/LiveParagraph.bend as Live
import ../src/DirectState.bend as State
import ./DirectCheck.bend as Check

def Driver.enqueue(window: Window, action: U32) -> IO(Window):
  import "./native_direct.c"

def Driver.inspect(window: Window, text: String, caret: U32) -> IO(Window):
  import "./native_direct.c"

def Driver.inspect_source(window: Window, source: String) -> IO(Window):
  import "./native_direct.c"

def checked_source(window: Window, +session: State.Session,
  rest: Window -> State.Session -> IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    checked : Window <- Driver.inspect_source(window, State.source(State.current(session)))
    rest(checked, session)

def step(window: Window, session: State.Session, action: U32,
  rest: Window -> State.Session -> IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    queued : Window <- Driver.enqueue(window, action)
    event : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish(event, session, w => s => checked_source(w, s, rest))

def after_delete(window: Window, session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), "**中文** xyz", 8n, 8n))
    checked : Window <- Driver.inspect(window, "中文 xyz", 4)
    Live.LiveParagraph.close(checked)
    IO.print("Native direct event loop passed")

def after_composition(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), "**中文** x😀yz", 4n, 4n))
    checked : Window <- Driver.inspect(window, "**中文** x😀yz", 4)
    step(checked, session, 6, after_delete)

def after_active(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), "**ab** x😀yz", 3n, 3n))
    checked : Window <- Driver.inspect(window, "**ab** x😀yz", 3)
    step(checked, session, 5, w => s => after_composition(w, s))

def after_redo(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), "**ab** x😀yz", 9n, 9n))
    checked : Window <- Driver.inspect(window, "ab x😀yz", 6)
    step(checked, session, 4, w => s => after_active(w, s))

def after_undo(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), "**ab** xyz", 8n, 8n))
    checked : Window <- Driver.inspect(window, "ab xyz", 4)
    step(checked, session, 3, w => s => after_redo(w, s))

def after_edit(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), "**ab** x😀yz", 9n, 9n))
    checked : Window <- Driver.inspect(window, "ab x😀yz", 6)
    step(checked, session, 2, w => s => after_undo(w, s))

def after_select(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), "**ab** xyz", 8n, 8n))
    checked : Window <- Driver.inspect(window, "ab xyz", 4)
    step(checked, session, 1, w => s => after_edit(w, s))

def main() -> IO(Unit):
  do IO<Unit>:
    +session : State.Session = State.start("**ab** xyz")
    opened : Window <- Live.LiveParagraph.open("**ab** xyz")
    shown : Window <- Live.LiveParagraph.present(opened, session)
    step(shown, session, 0, w => s => after_select(w, s))
