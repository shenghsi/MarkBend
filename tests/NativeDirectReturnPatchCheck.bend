import Base
import ../src/LiveParagraph.bend as Live
import ../src/DirectState.bend as State
import ./NativeReturnCheck.bend as Native
import ./NativeReturnPatchCheck.bend as Reference
import ./DirectCheck.bend as Check
import ./SessionViewCheck.bend as View

def valid(+session: State.Session, source: String, +caret: Nat) -> Bool:
  Check.snapshot_is(State.current(session), source, caret, caret) && View.valid(session)

def after_redo(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(valid(session, "**ab**\n- x\n- ", 13n))
    checked : Window <- Reference.inspected(window, "**ab**\n- x\n- ", 13n)
    Live.LiveParagraph.close(checked)
    IO.print("Native direct Return source range, stale selection, attributed scene, undo, and redo passed")

def after_undo(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(valid(session, "**ab**\n- x", 10n))
    checked : Window <- Reference.inspected(window, "**ab**\n- x", 10n)
    queued : Window <- Native.Driver.enqueue(checked, 3)
    update : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish(update, session, w => s => after_redo(w, s))

def after_return(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(valid(session, "**ab**\n- x\n- ", 13n))
    checked : Window <- Reference.inspected(window, "**ab**\n- x\n- ", 13n)
    queued : Window <- Native.Driver.enqueue(checked, 2)
    update : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish(update, session, w => s => after_undo(w, s))

def ready(window: Window, +session: State.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(valid(session, "**ab**\n- x", 0n))
    queued : Window <- Native.Driver.enqueue(window, 30)
    update : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish(update, session, w => s => after_return(w, s))

def main() -> IO(Unit):
  do IO<Unit>:
    window : Window <- Live.LiveParagraph.open("**ab**\n- x")
    Live.LiveParagraph.continue_session(window, State.start("**ab**\n- x"), w => s => ready(w, s))
