import Base
import ../src/StoredEditor.bend as Stored
import ../src/DirectState.bend as Editor
import ../src/LiveParagraph.bend as Live
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as Correct
import ./NativeDocumentBench.bend as Driver
import ./DirectCheck.bend as Check
import ../src/SessionRelease.bend as Release

def loaded(value: Maybe<&2, Stored.Session>) -> IO(Stored.Session):
  match value:
    case Some{session}:
      IO.pure(Stored.Session, Stored.request(session))
    case None{}:
      IO.die(Stored.Session, 1, "Native persistent benchmark load failed")

def accepted(window: Window, value: Stored.EditResult, selection: Nat & Nat,
  text: String, rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match value:
    case Stored.Accepted{+session}:
      match session:
        case Stored.Session{editor, storage}:
          Live.LiveParagraph.continue_edit_range(window, selection, editor, text,
            w => s => rest(w, session))
    case _:
      do IO<Unit>:
        Live.LiveParagraph.close(window)
        Check.check(False{})

def edit(update: Window & Live.ParagraphEvent, +session: Stored.Session,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  (window, event) = update
  match event session:
    case Live.ParagraphEdit{start, end, +text} Stored.Session{editor, storage}:
      +first = U32.to_nat(start)
      +last = U32.to_nat(end)
      accepted(window, Stored.edit(session, first, last, text),
        Editor.source_selection(Nat.is_eq(first, last), Editor.index(editor), first, last), text, rest)
    case _ _:
      do IO<Unit>:
        Live.LiveParagraph.close(window)
        Check.check(False{})

def after_edit(fuel: Nat, +count: Nat, window: Window, +session: Stored.Session,
  +source: String, +initial: Save.State) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        drawn : Window <- Driver.NativeDocument.frame(window, 1)
        Check.check(Correct.matches(session, source ++ String.repeat("X", count),
          Save.edit(Save.request(initial), Encode.bytes(Utf8.encode(source ++ String.repeat("X", count))))))
        Check.check(Stored.dirty(session))
        +close_start : Nat <- IO.now()
        Live.LiveParagraph.close(drawn)
        +closed : Nat <- IO.now()
        ticket : Chan(Bool) <- Release.begin(session)
        +dispatched : Nat <- IO.now()
        done : Bool <- Release.finish(ticket)
        +completed : Nat <- IO.now()
        Check.check(done)
        IO.print("native_session_close window_ms=" ++ Nat.show(Nat.sub(closed, close_start)) ++
          " dispatch_ms=" ++ Nat.show(Nat.sub(dispatched, closed)) ++
          " disposal_ms=" ++ Nat.show(Nat.sub(completed, closed)))
        IO.print("Native persistent document benchmark passed")
    case 1n+remaining:
      do IO<Unit>:
        drawn : Window <- Driver.NativeDocument.frame(window, 1)
        Check.check(Correct.matches(session, source ++ String.repeat("X", count),
          Save.edit(Save.request(initial), Encode.bytes(Utf8.encode(source ++ String.repeat("X", count))))))
        Check.check(Stored.dirty(session))
        queued : Window <- Driver.NativeDocument.enqueue(drawn, 1)
        update : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
        edit(update, session, w => s => after_edit(remaining, 1n+count, w, s, source, initial))

def opened(update: Window & Live.ParagraphEvent, +session: Stored.Session,
  source: String, initial: Save.State) -> IO(Unit):
  (window, event) = update
  do IO<Unit>:
    Driver.check_open_event(event)
    drawn : Window <- Driver.NativeDocument.frame(window, 0)
    scrolled : Window <- Driver.NativeDocument.scroll(drawn)
    queued : Window <- Driver.NativeDocument.enqueue(scrolled, 1)
    next : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
    edit(next, session, w => s => after_edit(19n, 1n, w, s, source, initial))

def start(+session: Stored.Session, +source: String, initial: Save.State) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      do IO<Unit>:
        window : Window <- Live.LiveParagraph.open(source)
        configured : Window <- Driver.NativeDocument.configure(window)
        shown : Window <- Live.LiveParagraph.present(configured, editor)
        ready : Window <- Driver.NativeDocument.presented(shown)
        queued : Window <- Driver.NativeDocument.enqueue(ready, 0)
        update : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(queued)
        opened(update, session, source, initial)

def main() -> IO(Unit):
  +source = Fixture.sample(1048576n)
  +initial = Save.open(Encode.bytes(Utf8.encode(source)))
  do IO<Unit>:
    Driver.NativeDocument.begin(1)
    session : Stored.Session <- loaded(Stored.load(initial))
    start(session, source, initial)
