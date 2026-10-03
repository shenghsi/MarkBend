import Base
import ../src/LiveParagraph.bend as Live
import ../src/StoredEditor.bend as Stored
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as State
import ./DirectCheck.bend as Check
import ../src/AppDocument.bend as App

def expected(step: Nat) -> String:
  match step:
    case 1n:
      "**ab** xyz"
    case _:
      "**中文** xyz\n"

def initial() -> Save.State:
  Save.State{Encode.bytes(Utf8.encode("**ab** xyz")), [100,105,115,107,13,10], 1n, None{}}

def verified(step: Nat, window: Window, +session: Stored.Session,
  more: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  +source = expected(step)
  do IO<Unit>:
    Check.check(State.matches(session, source,
      Save.edit(Save.request(initial()), Encode.bytes(Utf8.encode(source)))))
    more(window, session)

def verified_document(step: Nat, window: Window, +document: App.Document,
  more: Window -> App.Document -> IO(Unit)) -> IO(Unit):
  match document:
    case App.Document{App.Requested{path}, session}:
      do IO<Unit>:
        Check.check(String.eq(path, "./中文 document.md"))
        verified(step, window, session, w => s => more(w, document))
    case _:
      Check.check(False{})

def run(+fuel: Nat, window: Window, document: App.Document) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        Live.LiveParagraph.close(window)
        IO.print("Persistent app input loop source and save snapshots check passed")
    case 1n+remaining:
      do IO<Unit>:
        event : Window & Live.ParagraphEvent <- Live.LiveParagraph.next(window)
        Live.LiveParagraph.finish_document(event, document,
          w => d => verified_document(remaining, w, d, next_w => next_d => run(remaining, next_w, next_d)))

def opened(value: Maybe<&2, Stored.Session>) -> IO(Unit):
  match value:
    case None{}:
      Check.check(False{})
    case Some{session}:
      do IO<Unit>:
        window : Window <- Live.LiveParagraph.open("**ab** xyz")
        Live.LiveParagraph.continue_stored(window, Stored.request(session),
          w => s => run(3n, w, App.with_session(App.Requested{"./中文 document.md"}, s)))

def main() -> IO(Unit):
  opened(Stored.load(initial()))
