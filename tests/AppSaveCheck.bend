import Base
import ../src/AppSave.bend as Save
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Editor
import ../src/ByteBuffer.bend as Bytes
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./StoredEditorCheck.bend as Stored
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def source() -> String:
  "\u{FEFF}中文😀\r\né\0\n"

def destination() -> App.Destination:
  App.Resolved{"alias.md", "/fixture/中文.md", [80, 65, 84, 72, 49]}

def same_destination(value: App.Destination) -> Bool:
  match value:
    case App.Resolved{requested, path, identity}:
      String.eq(requested, "alias.md") && String.eq(path, "/fixture/中文.md") &&
        Flat.bytes_equal(identity, [80, 65, 84, 72, 49])
    case _:
      False{}

def same_document(value: App.Document, text: String, state: Flat.State) -> Bool:
  match value:
    case App.Document{destination, session}:
      same_destination(destination) && Stored.matches(session, text, state)

def ready(value: Save.Preparation, expected: Flat.State) -> IO(App.Document):
  match value:
    case Save.Ready{+document, Save.Request{path, identity, id, baseline, bytes}}:
      do IO<App.Document>:
        Check.check(same_document(document, source(), expected))
        Check.check(String.eq(path, "/fixture/中文.md"))
        Check.check(Flat.bytes_equal(identity, [80, 65, 84, 72, 49]))
        Check.check(Nat.is_eq(id, 0n))
        Check.check(Flat.bytes_equal(Bytes.materialize(baseline), [65]))
        Check.check(Flat.bytes_equal(Bytes.materialize(bytes), Encode.bytes(Utf8.encode(source()))))
        return document
    case _:
      IO.die(App.Document, 1, "App save request was not ready")

def no_second_writer(value: Save.Preparation, expected: Flat.State) -> Bool:
  match value:
    case Save.Pending{document}:
      same_document(document, source(), expected)
    case _:
      False{}

def kept(value: Save.CloseDecision, text: String, expected: Flat.State) -> Bool:
  match value:
    case Save.KeepOpen{document}:
      same_document(document, text, expected)
    case _:
      False{}

def closed(value: Save.CloseDecision, text: String, expected: Flat.State) -> Bool:
  match value:
    case Save.CloseNow{document}:
      same_document(document, text, expected)
    case _:
      False{}

def save_first(value: Save.CloseDecision, text: String, expected: Flat.State) -> Bool:
  match value:
    case Save.SaveFirst{document}:
      same_document(document, text, expected)
    case _:
      False{}

def later(document: App.Document) -> IO(App.Document):
  match document:
    case App.Document{destination, session}:
      do IO<App.Document>:
        edited : Editor.Session <- Stored.accepted(Editor.replace_source(session, "later😀"))
        return App.with_session(destination, edited)

def undo(document: App.Document) -> App.Document:
  match document:
    case App.Document{destination, session}:
      App.with_session(destination, Editor.undo(session))

def redo(document: App.Document) -> App.Document:
  match document:
    case App.Document{destination, session}:
      App.with_session(destination, Editor.redo(session))

def unavailable(value: Save.Preparation) -> Bool:
  match value:
    case Save.Unavailable{App.Document{App.Untitled{}, session}}:
      Stored.matches(session, "A", Flat.open([65]))
    case Save.Unavailable{App.Document{App.Requested{path}, session}}:
      String.eq(path, "requested.md") && Stored.matches(session, "A", Flat.open([65]))
    case _:
      False{}

def retry(value: Save.Preparation, expected: Flat.State) -> IO(App.Document):
  match value:
    case Save.Ready{+document, Save.Request{path, identity, id, baseline, bytes}}:
      do IO<App.Document>:
        Check.check(same_document(document, source(), expected))
        Check.check(String.eq(path, "/fixture/中文.md"))
        Check.check(Flat.bytes_equal(identity, [80, 65, 84, 72, 49]))
        Check.check(Nat.is_eq(id, 1n))
        Check.check(Flat.bytes_equal(Bytes.materialize(baseline), [65]))
        Check.check(Flat.bytes_equal(Bytes.materialize(bytes), Encode.bytes(Utf8.encode(source()))))
        return document
    case _:
      IO.die(App.Document, 1, "App save retry was not ready")

def main() -> IO(Unit):
  +bytes = Encode.bytes(Utf8.encode(source()))
  +initial = Flat.open([65])
  +dirty = Flat.edit(initial, bytes)
  +pending = Flat.request(dirty)
  +confirmed = Flat.complete(pending, 0n, Flat.Confirmed{})
  do IO<Unit>:
    +session : Editor.Session <- Stored.loaded(Editor.load(initial))
    +edited : Editor.Session <- Stored.accepted(Editor.replace_source(session, source()))
    +document : App.Document <- ready(Save.prepare(App.with_session(destination(), edited)), pending)
    Check.check(no_second_writer(Save.prepare(document), pending))
    Check.check(same_document(Save.complete(document, 7n, Save.Confirmed{}), source(), pending))
    Check.check(kept(Save.close_requested(document), source(), pending))
    Check.check(kept(Save.choose_close(document, Save.CancelChoice{}), source(), pending))
    Check.check(closed(Save.choose_close(document, Save.DiscardChoice{}), source(), pending))
    Check.check(save_first(Save.choose_close(document, Save.SaveChoice{}), source(), pending))
    Check.check(same_document(Save.complete(document, 0n, Save.Conflict{}), source(),
      Flat.complete(pending, 0n, Flat.OldKept{})))
    Check.check(same_document(Save.complete(document, 0n, Save.UnavailableHost{}), source(),
      Flat.complete(pending, 0n, Flat.OldKept{})))
    Check.check(kept(Save.close_requested(Save.complete(document, 0n, Save.Uncertain{})), source(), pending))
    +done : App.Document <- IO.pure(App.Document, Save.complete(document, 0n, Save.Confirmed{}))
    Check.check(closed(Save.close_requested(done), source(), confirmed))
    +newer : App.Document <- later(document)
    +saved_later : App.Document <- IO.pure(App.Document, Save.complete(newer, 0n, Save.Confirmed{}))
    Check.check(kept(Save.close_requested(saved_later), "later😀", Flat.edit(confirmed,
      Encode.bytes(Utf8.encode("later😀")))))
    Check.check(closed(Save.close_requested(undo(saved_later)), source(), confirmed))
    Check.check(same_document(redo(undo(saved_later)), "later😀", Flat.edit(confirmed,
      Encode.bytes(Utf8.encode("later😀")))))
    # Undo restores the baseline, but an uncertain pending operation still blocks close.
    Check.check(kept(Save.close_requested(undo(document)), "A", Flat.edit(pending, [65])))
    +retry_state : Flat.State <- IO.pure(Flat.State,
      Flat.request(Flat.complete(pending, 0n, Flat.OldKept{})))
    +retried : App.Document <- retry(Save.prepare(Save.complete(document, 0n, Save.OldKept{})), retry_state)
    conflict_retry : App.Document <- retry(Save.prepare(Save.complete(document, 0n, Save.Conflict{})), retry_state)
    Check.check(same_document(conflict_retry, source(), retry_state))
    Check.check(same_document(Save.complete(retried, 0n, Save.Confirmed{}), source(), retry_state))
    Check.check(kept(Save.close_completed(undo(Save.complete(document, 0n, Save.OldKept{})),
      Save.OldKept{}), "A", Flat.edit(Flat.complete(pending, 0n, Flat.OldKept{}), [65])))
    Check.check(closed(Save.close_completed(done, Save.Confirmed{}), source(), confirmed))
    Check.check(unavailable(Save.prepare(App.with_session(App.Untitled{}, session))))
    Check.check(unavailable(Save.prepare(App.with_session(App.Requested{"requested.md"}, session))))
    IO.print("App save tickets, later edits, history, and close decisions passed")
