import Base
import ./DirectState.bend as Editor
import ./StorageHistory.bend as History
import ./PersistentSave.bend as Save
import ./SaveState.bend as Flat
import ./Utf8.bend as Utf8

type Session is Data:
  Session{editor: Editor.Session, storage: History.Session}

type EditResult is Data:
  Accepted{session: Session}
  Rejected{session: Session}

def load(+state: Flat.State) -> Maybe<&2, Session>:
  match state:
    case Flat.State{current, saved, next, pending}:
      do Maybe<&2, Session>:
        source : String <- Utf8.decode(current)
        storage : History.Session <- History.load(state)
        return Session{Editor.start(source), storage}

def edited(value: History.EditResult, original: Session, +start: Nat,
  +end: Nat, text: String) -> EditResult:
  match value original:
    case History.Accepted{storage} Session{editor, old_storage}:
      Accepted{Session{Editor.edit(editor, start, end, text), storage}}
    case History.Rejected{storage} original:
      Rejected{original}

def at_selection(selected: Editor.Snapshot, +original: Session,
  native_start: Nat, native_end: Nat, +text: String) -> EditResult:
  match selected original:
    case Editor.Snapshot{start, end, document} Session{editor, storage}:
      edited(History.edit(storage, start, end, text), original,
        native_start, native_end, text)

# Use the same native-to-source mapping as the formatted editor. Storage
# validation must succeed before either editor or storage history is replaced.
def edit(+session: Session, +start: Nat, +end: Nat, +text: String) -> EditResult:
  match session:
    case Session{+editor, storage}:
      at_selection(Editor.select_snapshot(Editor.current(editor), Editor.index(editor), start, end),
        session, start, end, text)

def select(session: Session, start: Nat, end: Nat) -> Session:
  match session:
    case Session{editor, storage}:
      Session{Editor.select(editor, start, end), storage}

def source_edited(value: History.EditResult, original: Session, start: Nat,
  end: Nat, text: String) -> EditResult:
  match value original:
    case History.Accepted{storage} Session{editor, old_storage}:
      Accepted{Session{Editor.edit_source(editor, start, end, text), storage}}
    case History.Rejected{storage} original:
      Rejected{original}

# The caller maps the incoming selection once before it chooses a source edit.
# Storage validation precedes changes to the editor and both history stores.
def source_edit_allowed(valid: Bool, +session: Session, +start: Nat, +end: Nat,
  +text: String) -> EditResult:
  match valid session:
    case True{} Session{editor, storage}:
      source_edited(History.edit(storage, start, end, text), session, start, end, text)
    case False{} original:
      Rejected{original}

def edit_source(+session: Session, +start: Nat, +end: Nat, text: String) -> EditResult:
  match session:
    case Session{editor, storage}:
      source_edit_allowed(Nat.is_le(Nat.max(start, end), Editor.source_length(Editor.current(editor))),
        session, start, end, text)

def replaced(value: History.EditResult, original: Session, text: String) -> EditResult:
  match value original:
    case History.Accepted{storage} Session{editor, old_storage}:
      Accepted{Session{Editor.replace_source(editor, text), storage}}
    case History.Rejected{storage} original:
      Rejected{original}

# A full-source host event is a separate operation from a local native edit.
def replace_source(+session: Session, +text: String) -> EditResult:
  match session:
    case Session{editor, storage}:
      replaced(History.replace_source(storage, text), session, text)

def undo(session: Session) -> Session:
  match session:
    case Session{editor, storage}:
      next_editor next_storage = Editor.undo(editor) History.undo(storage)
      Session{next_editor, next_storage}

def redo(session: Session) -> Session:
  match session:
    case Session{editor, storage}:
      next_editor next_storage = Editor.redo(editor) History.redo(storage)
      Session{next_editor, next_storage}

def request(session: Session) -> Session:
  match session:
    case Session{editor, storage}:
      Session{editor, History.request(storage)}

def complete(session: Session, id: Nat, outcome: Flat.Outcome) -> Session:
  match session:
    case Session{editor, storage}:
      Session{editor, History.complete(storage, id, outcome)}

def dirty(session: Session) -> Bool:
  match session:
    case Session{editor, storage}:
      History.dirty(storage)

def clear_history(session: Session) -> Session:
  match session:
    case Session{editor, storage}:
      next_editor next_storage = Editor.clear_history(editor) History.clear_history(storage)
      Session{next_editor, next_storage}
