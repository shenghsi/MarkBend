import Base
import ../src/AppInput.bend as Input
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./StoredEditorCheck.bend as Stored
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def text() -> String:
  "\u{FEFF}中文😀\r\né\0\n"

def document(session: Editor.Session) -> App.Document:
  App.Document{App.Resolved{"alias.md", "/fixture/中文.md", [1, 2, 3]}, session}

def same(value: App.Document, source: String, state: Save.State) -> Bool:
  match value:
    case App.Document{App.Resolved{requested, path, identity}, session}:
      String.eq(requested, "alias.md") && String.eq(path, "/fixture/中文.md") &&
        Save.bytes_equal(identity, [1, 2, 3]) && Stored.matches(session, source, state)
    case _:
      False{}

def suspended(value: Input.Ended, source: String, state: Save.State) -> Bool:
  match value:
    case Input.Suspended{document}:
      same(document, source, state)
    case _:
      False{}

def clean(value: Input.Ended) -> Bool:
  match value:
    case Input.CloseSafe{document}:
      same(document, "A", Save.open([65]))
    case _:
      False{}

def retained(value: Input.Continuation, source: String, state: Save.State) -> Bool:
  match value:
    case Input.Retained{document}:
      same(document, source, state)
    case _:
      False{}

def history(value: Input.Continuation, +pending: Save.State) -> Bool:
  match value:
    case Input.Running{App.Document{destination, +session}}:
      Stored.matches(session, text(), pending) &&
        Stored.matches(Editor.undo(session), "A", Save.edit(pending, [65])) &&
        same(App.with_session(destination, Editor.redo(Editor.undo(session))), text(), pending)
    case _:
      False{}

def main() -> IO(Unit):
  +dirty = Save.edit(Save.open([65]), Encode.bytes(Utf8.encode(text())))
  +pending = Save.request(dirty)
  do IO<Unit>:
    +initial : Editor.Session <- Stored.loaded(Editor.load(Save.open([65])))
    +edited : Editor.Session <- Stored.accepted(Editor.replace_source(initial, text()))
    +saving : Editor.Session = Editor.request(edited)
    Check.check(clean(Input.ended(document(initial))))
    Check.check(suspended(Input.ended(document(edited)), text(), dirty))
    Check.check(suspended(Input.ended(document(saving)), text(), pending))
    # Equality with the baseline is insufficient while a ticket remains pending.
    Check.check(suspended(Input.ended(document(Editor.undo(saving))), "A", Save.edit(pending, [65])))
    Check.check(retained(Input.resume(document(saving), Input.Unavailable{}), text(), pending))
    Check.check(history(Input.resume(document(saving), Input.Resumed{}), pending))
    IO.print("Input-ended decisions retained metadata, bytes, pending save, and history")
