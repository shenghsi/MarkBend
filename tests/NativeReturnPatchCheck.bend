import Base
import ../src/LiveParagraph.bend as Live
import ../src/StoredEditor.bend as Stored
import ../src/DirectState.bend as State
import ../src/BlockScene.bend as Scene
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as Storage
import ./ReturnCommandCheck.bend as Result
import ./NativeReturnCheck.bend as Native
import ./DirectCheck.bend as Check

def PatchDriver.inspect(window: Window, runs: List<&2, Scene.Run>) -> IO(Window):
  import "./native_return_patch.c"

def expected(window: Window, scene: Scene.Scene) -> IO(Window):
  match scene:
    case Scene.Scene{runs, points}:
      PatchDriver.inspect(window, runs)

def initial() -> Flat.State:
  Flat.open(Encode.bytes(Utf8.encode("**ab**\n- x")))

def saved() -> Flat.State:
  Flat.edit(initial(), Encode.bytes(Utf8.encode("**ab**\n- x\n- ")))

def inspected(window: Window, +source: String, +position: Nat) -> IO(Window):
  +reference = Scene.build(source, position, position)
  +visible = Scene.text(reference)
  do IO<Window>:
    checked : Window <- Native.Driver.inspect_source(window, source)
    selected : Window <- Native.Driver.inspect(checked, visible, U32.from_nat(String.length(visible)))
    expected(selected, reference)

def after_redo(window: Window, +session: Stored.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Result.verified(session, "**ab**\n- x\n- ", 13n, 13n, saved()))
    checked : Window <- inspected(window, "**ab**\n- x\n- ", 13n)
    Live.LiveParagraph.close(checked)
    IO.print("Native Return stale selection, composed patches, full attributed reference, undo, and redo passed")

def after_undo(window: Window, +session: Stored.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Result.verified(session, "**ab**\n- x", 10n, 10n, initial()))
    checked : Window <- inspected(window, "**ab**\n- x", 10n)
    queued : Window <- Native.Driver.enqueue(checked, 3)
    update : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish_stored(update, session, w => s => after_redo(w, s))

def after_return(window: Window, +session: Stored.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Result.verified(session, "**ab**\n- x\n- ", 13n, 13n, saved()))
    checked : Window <- inspected(window, "**ab**\n- x\n- ", 13n)
    queued : Window <- Native.Driver.enqueue(checked, 2)
    update : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish_stored(update, session, w => s => after_undo(w, s))

def ready(window: Window, +session: Stored.Session) -> IO(Unit):
  do IO<Unit>:
    Check.check(Result.verified(session, "**ab**\n- x", 0n, 0n, initial()))
    # Action 30 sets the native caret and sends Return without a Bend selection event.
    queued : Window <- Native.Driver.enqueue(window, 30)
    update : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish_stored(update, session, w => s => after_return(w, s))

def main() -> IO(Unit):
  do IO<Unit>:
    session : Stored.Session <- Storage.loaded(Stored.load(initial()))
    window : Window <- Live.LiveParagraph.open("**ab**\n- x")
    Live.LiveParagraph.continue_stored(window, session, w => s => ready(w, s))
