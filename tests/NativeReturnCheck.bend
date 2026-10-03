import Base
import ../src/LiveParagraph.bend as Live
import ../src/StoredEditor.bend as Stored
import ../src/DirectState.bend as State
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as Storage
import ./ReturnCommandCheck.bend as Result
import ./DirectCheck.bend as Check

def Driver.enqueue(window: Window, action: U32) -> IO(Window):
  import "./native_direct.c"

def Driver.inspect(window: Window, text: String, caret: U32) -> IO(Window):
  import "./native_direct.c"

def Driver.inspect_source(window: Window, source: String) -> IO(Window):
  import "./native_direct.c"

def after_return(window: Window, +session: Stored.Session) -> IO(Unit):
  +initial = Flat.open(Encode.bytes(Utf8.encode("- 中😀")))
  do IO<Unit>:
    Check.check(Result.verified(session, "- 中😀\n- ", 7n, 7n,
      Flat.edit(initial, Encode.bytes(Utf8.encode("- 中😀\n- ")))))
    Check.check(Result.verified(Stored.undo(session), "- 中😀", 4n, 4n, initial))
    source_checked : Window <- Driver.inspect_source(window, "- 中😀\n- ")
    checked : Window <- Driver.inspect(source_checked, "- 中😀\n- ", 8)
    Live.LiveParagraph.close(checked)
    IO.print("Native Return command, exact source, formatted view, selection, and undo passed")

def ready(window: Window, session: Stored.Session) -> IO(Unit):
  do IO<Unit>:
    queued : Window <- Driver.enqueue(window, 30)
    event : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    Live.LiveParagraph.finish_stored(event, session, w => s => after_return(w, s))

def main() -> IO(Unit):
  do IO<Unit>:
    session : Stored.Session <- Storage.loaded(Stored.load(Flat.open(Encode.bytes(Utf8.encode("- 中😀")))))
    window : Window <- Live.LiveParagraph.open("- 中😀")
    Live.LiveParagraph.continue_stored(window, session, ready)
