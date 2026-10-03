import Base
import ../src/LiveParagraph.bend as Live
import ../src/DirectState.bend as State
import ./DirectCheck.bend as Check

def Driver.enqueue(window: Window, action: U32) -> IO(Window):
  import "./native_navigation.c"

def Driver.expected() -> IO(U32):
  import "./native_navigation.c"

def Driver.inspect(window: Window, text: String, start: U32, length: U32) -> IO(Window):
  import "./native_navigation.c"

def source() -> String:
  "中文😀é👩‍💻\n" ++ String.repeat("x", 8192n)

def verify(window: Window, +session: State.Session, start: Nat, end: Nat,
  native: U32, length: U32, rest: Window -> State.Session -> IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), source(), start, end))
    checked : Window <- Driver.inspect(window, source(), native, length)
    rest(checked, session)

def step(window: Window, session: State.Session, action: U32,
  start: Nat, end: Nat, native: U32, length: U32,
  rest: Window -> State.Session -> IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    queued : Window <- Driver.enqueue(window, action)
    event : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish(event, session,
      w => s => verify(w, s, start, end, native, length, rest))

def finish(window: Window, session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Live.LiveParagraph.close(window)
    IO.print("Native navigation and resize batch passed")

def resize_window(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 15, 8n, 8n, 11, 0, finish)

def resize(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 12, 8n, 8n, 11, 0, resize_window)

def after_line(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 11, 8n, 8n, 11, 0, resize)

def after_joiner(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 10, 9n, 9n, 12, 0, after_line)

def after_combining(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 9, 8n, 8n, 11, 0, after_joiner)

def after_emoji(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 8, 5n, 5n, 6, 0, after_combining)

def after_chinese(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 7, 3n, 3n, 4, 0, after_emoji)

def after_first(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 6, 2n, 2n, 2, 0, after_chinese)

def after_begin(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 5, 1n, 1n, 1, 0, after_first)

def after_up(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 14, 0n, 0n, 0, 0, after_begin)

def column_restore(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 19, 9n, 9n, 12, 0, after_up)

def column_up(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 17, 14n, 14n, 17, 0, column_restore)

def column_position(window: Window, session: State.Session, +native: U32) -> IO(Unit):
  +position = U32.to_nat((native - 3 : U32))
  verify(window, session, position, position, native, 0, column_up)

def column_verify(window: Window, session: State.Session) -> IO(Unit):
  do IO<Unit>:
    native : U32 <- Driver.expected()
    column_position(window, session, native)

def column_down(window: Window, session: State.Session) -> IO(Unit):
  do IO<Unit>:
    queued : Window <- Driver.enqueue(window, 16)
    event : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish(event, session, column_verify)

def column_start(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 18, 14n, 14n, 17, 0, column_down)

def wrapped_up(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 17, 9n, 9n, 12, 0, column_start)

def wrapped_position(window: Window, session: State.Session, +native: U32) -> IO(Unit):
  +position = U32.to_nat((native - 3 : U32))
  verify(window, session, position, position, native, 0, wrapped_up)

def wrapped_verify(window: Window, session: State.Session) -> IO(Unit):
  do IO<Unit>:
    native : U32 <- Driver.expected()
    wrapped_position(window, session, native)

def wrapped(window: Window, session: State.Session) -> IO(Unit):
  do IO<Unit>:
    queued : Window <- Driver.enqueue(window, 16)
    event : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish(event, session, wrapped_verify)

def after_down(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 13, 9n, 9n, 12, 0, wrapped)

def after_selection(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 4, 0n, 0n, 0, 0, after_down)

def after_right(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 3, 0n, 8201n, 0, 8204, after_selection)

def after_left(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 2, 8201n, 8201n, 8204, 0, after_right)

def after_end(window: Window, session: State.Session) -> IO(Unit):
  step(window, session, 1, 8200n, 8200n, 8203, 0, after_left)

def main() -> IO(Unit):
  +text = source()
  +session = State.start(text)
  do IO<Unit>:
    opened : Window <- Live.LiveParagraph.open(text)
    shown : Window <- Live.LiveParagraph.present(opened, session)
    step(shown, session, 0, 8201n, 8201n, 8204, 0, after_end)
