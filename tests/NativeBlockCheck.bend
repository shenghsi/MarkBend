import Base
import ../src/LiveParagraph.bend as Live
import ../src/DirectState.bend as State
import ./DirectCheck.bend as Check
import ./NativeDirectCheck.bend as Driver

def BlockStyle.check(window: Window) -> IO(Window):
  import "./native_block_style.c"

def source() -> String:
  "# h\n\n```rs\n**x** *y* `z`\n```\n\ntail"

def after_leave(window: Window, session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), source(), 32n, 32n))
    checked : Window <- Driver.Driver.inspect(window, "h\n\n**x** *y* `z`\n\ntail", 20)
    styled : Window <- BlockStyle.check(checked)
    Live.LiveParagraph.close(styled)
    IO.print("Native block event loop passed")

def after_undo(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), source(), 12n, 12n))
    checked : Window <- Driver.Driver.inspect(window,
      "h\n\n```rs\n**x** *y* `z`\n```\n\ntail", 10)
    Driver.step(checked, session, 24, after_leave)

def after_edit(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session),
      "# h\n\n```rs\n*Xx** *y* `z`\n```\n\ntail", 13n, 13n))
    checked : Window <- Driver.Driver.inspect(window,
      "h\n\n```rs\n*Xx** *y* `z`\n```\n\ntail", 11)
    Driver.step(checked, session, 2, w => s => after_undo(w, s))

def after_select(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), source(), 12n, 12n))
    checked : Window <- Driver.Driver.inspect(window,
      "h\n\n```rs\n**x** *y* `z`\n```\n\ntail", 10)
    Driver.step(checked, session, 22, w => s => after_edit(w, s))

def after_tail(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Check.snapshot_is(State.current(session), source(), 32n, 32n))
    checked : Window <- Driver.Driver.inspect(window, "h\n\n**x** *y* `z`\n\ntail", 20)
    styled : Window <- BlockStyle.check(checked)
    Driver.step(styled, session, 21, w => s => after_select(w, s))

def main() -> IO(Unit):
  do IO<Unit>:
    +session : State.Session = State.start(source())
    opened : Window <- Live.LiveParagraph.open(source())
    shown : Window <- Live.LiveParagraph.present(opened, session)
    Driver.step(shown, session, 20, w => s => after_tail(w, s))
