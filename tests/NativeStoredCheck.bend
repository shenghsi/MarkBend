import Base
import ../src/StoredEditor.bend as Stored
import ../src/DirectState.bend as Editor
import ../src/StorageHistory.bend as History
import ../src/PersistentSave.bend as Save
import ../src/SaveState.bend as Flat
import ../src/LiveParagraph.bend as Live
import ../src/Utf8.bend as Utf8
import ./NativeDirectCheck.bend as Driver
import ./RecoveryEditorCheck.bend as Encode
import ./SaveStateCheck.bend as States
import ./TextStorageCheck.bend as Text
import ./DirectCheck.bend as Check
import ../src/AppDocument.bend as App


def checked(window: Window, +session: Stored.Session,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match session:
    case Stored.Session{+editor, History.Session{current, undo, redo, save, identity}}:
      +source = Editor.source(Editor.current(editor))
      do IO<Unit>:
        Check.check(Text.matches(current, source))
        Check.check(States.state_equal(Save.materialize(save),
          Flat.State{Encode.bytes(Utf8.encode(source)), [100,105,115,107,13,10], 2n,
            Some{Flat.Ticket{1n, Encode.bytes(Utf8.encode("**ab** xyz"))}}}))
        verified : Window <- Driver.Driver.inspect_source(window, source)
        rest(verified, session)

def checked_document(window: Window, document: App.Document,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match document:
    case App.Document{App.Requested{path}, session}:
      do IO<Unit>:
        Check.check(String.eq(path, "./中文 document.md"))
        checked(window, session, rest)
    case _:
      Check.check(False{})

def present(window: Window, +session: Stored.Session,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      do IO<Unit>:
        shown : Window <- Live.LiveParagraph.present(window, editor)
        checked(shown, session, rest)

def present_replacement(window: Window, value: Stored.EditResult,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match value:
    case Stored.Accepted{session}:
      present(window, session, rest)
    case Stored.Rejected{session}:
      present(window, session, rest)

def edited(window: Window, value: Stored.EditResult, selection: Nat & Nat,
  text: String, rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match value:
    case Stored.Accepted{+session}:
      match session:
        case Stored.Session{editor, storage}:
          match selection:
            case (start, end):
              do IO<Unit>:
                changed : Window <- Live.LiveParagraph.replace(window, start, end, text)
                shown : Window <- Live.LiveParagraph.present_view(changed, editor)
                checked(shown, session, rest)
    case _:
      do IO<Unit>:
        Live.LiveParagraph.close(window)
        Check.check(False{})

def finish_event(update: Window & Live.ParagraphEvent, +session: Stored.Session,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  Live.LiveParagraph.finish_document(update,
    App.Document{App.Requested{"./中文 document.md"}, session},
    w => d => checked_document(w, d, rest))

def replacement_undone(window: Window, session: Stored.Session) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      do IO<Unit>:
        Check.check(Check.snapshot_is(Editor.current(editor), "**中文** xyz", 8n, 8n))
        Live.LiveParagraph.close(window)
        IO.print("Native persistent editor input, composition, history, and save check passed")

def source_replaced(window: Window, +session: Stored.Session) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      do IO<Unit>:
        Check.check(Check.snapshot_is(Editor.current(editor), "# 新😀\r\n", 6n, 6n))
        finish_event((window, Live.ParagraphUndo{}), session, replacement_undone)

def rejected_source(window: Window, +session: Stored.Session) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      do IO<Unit>:
        Check.check(Check.snapshot_is(Editor.current(editor), "**中文** xyz", 8n, 8n))
        finish_event((window, Live.ParagraphChanged{"# 新😀\r\n"}), session,
          w => s => source_replaced(w, s))

def run(fuel: Nat, +action: U32, window: Window, +session: Stored.Session) -> IO(Unit):
  match fuel:
    case 0n:
      match session:
        case Stored.Session{editor, storage}:
          do IO<Unit>:
            Check.check(Check.snapshot_is(Editor.current(editor), "**中文** xyz", 8n, 8n))
            inspected : Window <- Driver.Driver.inspect(window, "中文 xyz", 4)
            finish_event((inspected, Live.ParagraphChanged{SCon{Char.from_u32(55296), SNil{}}}), session,
              w => s => rejected_source(w, s))
    case 1n+remaining:
      do IO<Unit>:
        queued : Window <- Driver.Driver.enqueue(window, action)
        update : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
        finish_event(update, session, w => s => run(remaining, (action + 1 : U32), w, s))

def start(+saving: Stored.Session) -> IO(Unit):
  match saving:
    case Stored.Session{editor, storage}:
      do IO<Unit>:
        window : Window <- Live.LiveParagraph.open("**ab** xyz")
        shown : Window <- Live.LiveParagraph.present(window, editor)
        run(7n, 0, shown, saving)

def opened(value: Maybe<&2, Stored.Session>) -> IO(Unit):
  match value:
    case Some{session}:
      start(Stored.request(session))
    case None{}:
      Check.check(False{})

def main() -> IO(Unit):
  opened(Stored.load(Flat.State{Encode.bytes(Utf8.encode("**ab** xyz")),
    [100,105,115,107,13,10], 1n, None{}}))
