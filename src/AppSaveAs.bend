import Base
import ./AppDocument.bend as App
import ./AppSave.bend as Save
import ./StoredEditor.bend as Editor
import ./StorageHistory.bend as History
import ./PersistentSave.bend as Persistent
import ./ByteBuffer.bend as Bytes
import ./SaveState.bend as Flat
import ./Utf8.bend as Utf8
import ./ResolvedOpen.bend as Resolved

# A host supplies this target only after resolving its canonical parent and
# validating a new leaf. Identity is opaque host data, never user text alone.
type Target is Data:
  Target{requested: String, path: String, identity: List<&2, U32>, parent_identity: List<&2, U32>}

type Candidate is Data:
  Cancelled{}
  Unavailable{}
  Rejected{message: String}
  Validated{target: Target}

# The proposed target stays outside App.Document until confirmed completion.
# The app must own this outer state before it can expose Save As controls.
type Workspace is Data:
  Editing{document: App.Document}
  Saving{document: App.Document, target: Target, id: Nat, snapshot: Bytes.Buffer}
  Uncertain{document: App.Document, target: Target, id: Nat, snapshot: Bytes.Buffer}

def valid_text(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{+char, rest}:
      Bool.not(Char.is_eq(char, Chr{0})) && Utf8.scalar(Char.to_u32(char)) && valid_text(rest)

def path_leaf(path: String, +leaf: String) -> Bool:
  match path:
    case SNil{}:
      Bool.not(String.is_empty(leaf)) && Bool.not(String.eq(leaf, ".")) && Bool.not(String.eq(leaf, ".."))
    case SCon{Chr{47}, rest}:
      path_leaf(rest, "")
    case SCon{char, rest}:
      path_leaf(rest, SCon{char, leaf})

def valid_path(+path: String) -> Bool:
  match path:
    case SCon{Chr{47}, rest}:
      valid_text(path) && path_leaf(rest, "")
    case _:
      False{}

def valid(target: Target) -> Bool:
  match target:
    case Target{+requested, path, key <> keys, parent <> parents}:
      Bool.not(String.is_empty(requested)) && valid_text(requested) && valid_path(path) &&
        Resolved.valid_bytes(key <> keys, True{}) && Resolved.valid_bytes(parent <> parents, True{})
    case _:
      False{}

def captured(document: App.Document, target: Target) -> Workspace:
  match document:
    case App.Document{destination, Editor.Session{editor,
      History.Session{current, undo, redo,
        Persistent.State{bytes, baseline, next, Some{Persistent.Ticket{+id, +snapshot}}}, state}}}:
      Saving{document, target, id, snapshot}
    case document:
      Editing{document}

def start_allowed(ok: Bool, document: App.Document, target: Target) -> Workspace:
  match ok document:
    case True{} App.Document{destination, session}:
      captured(App.with_session(destination, Editor.request(session)), target)
    case False{} document:
      Editing{document}

def start(value: Workspace, candidate: Candidate) -> Workspace:
  match value candidate:
    case Editing{App.Document{destination, +session}} Validated{+target}:
      start_allowed(valid(target) && Bool.not(Save.pending(session)), App.with_session(destination, session), target)
    case value _:
      value

def adopted(target: Target, session: Editor.Session) -> App.Document:
  match target:
    case Target{requested, path, identity, parent_identity}:
      App.with_session(App.Resolved{requested, path, identity}, session)

# Internal result handler. The host must enter through complete, which checks
# both the active transaction and the retained session ticket.
def finished(same: Bool, value: Workspace, outcome: Save.Outcome) -> Workspace:
  match same value outcome:
    case True{} Saving{App.Document{destination, session}, target, id, snapshot} Save.Confirmed{}:
      Editing{adopted(target, Editor.complete(session, id, Flat.Confirmed{}))}
    case True{} Saving{document, target, id, snapshot} Save.Uncertain{}:
      Uncertain{document, target, id, snapshot}
    case True{} Saving{document, target, id, snapshot} _:
      Editing{Save.complete(document, id, outcome)}
    case _ value _:
      value

# Uncertain publication cannot accept a retry or a normal completion. A later
# stable observation and synchronization need a separate reconciliation rule.
def ticket_matches(session: Editor.Session, id: Nat, snapshot: Bytes.Buffer) -> Bool:
  match session:
    case Editor.Session{editor, History.Session{current, undo, redo,
      Persistent.State{bytes, baseline, next, Some{Persistent.Ticket{active, captured}}}, state}}:
      Nat.is_eq(id, active) && Bytes.equal(snapshot, captured)
    case _:
      False{}

def matches(value: Workspace, id: Nat) -> Bool:
  match value:
    case Saving{App.Document{destination, session}, target, +active, snapshot}:
      Nat.is_eq(active, id) && ticket_matches(session, active, snapshot)
    case _:
      False{}

def complete(+value: Workspace, id: Nat, outcome: Save.Outcome) -> Workspace:
  finished(matches(value, id), value, outcome)

def updated(ok: Bool, value: Workspace, session: Editor.Session) -> Workspace:
  match ok:
    case False{}:
      value
    case True{}:
      match value:
        case Editing{App.Document{destination, old}}:
          Editing{App.with_session(destination, session)}
        case Saving{App.Document{destination, old}, target, id, snapshot}:
          Saving{App.with_session(destination, session), target, id, snapshot}
        case Uncertain{App.Document{destination, old}, target, id, snapshot}:
          Uncertain{App.with_session(destination, session), target, id, snapshot}

# Internal edit result. The supported entry points below derive the replacement
# from the retained session. There is no arbitrary session-replacement API.
def edit_finished(result: Editor.EditResult, value: Workspace) -> Workspace:
  match result:
    case Editor.Accepted{session}:
      updated(True{}, value, session)
    case Editor.Rejected{session}:
      value

def replace_source(+value: Workspace, +text: String) -> Workspace:
  match value:
    case Editing{App.Document{destination, +session}}:
      edit_finished(Editor.replace_source(session, text), value)
    case Saving{App.Document{destination, +session}, target, id, snapshot}:
      edit_finished(Editor.replace_source(session, text), value)
    case Uncertain{App.Document{destination, +session}, target, id, snapshot}:
      edit_finished(Editor.replace_source(session, text), value)

def undo(+value: Workspace) -> Workspace:
  match value:
    case Editing{App.Document{destination, +session}}:
      updated(True{}, value, Editor.undo(session))
    case Saving{App.Document{destination, +session}, target, id, snapshot}:
      updated(True{}, value, Editor.undo(session))
    case Uncertain{App.Document{destination, +session}, target, id, snapshot}:
      updated(True{}, value, Editor.undo(session))

def redo(+value: Workspace) -> Workspace:
  match value:
    case Editing{App.Document{destination, +session}}:
      updated(True{}, value, Editor.redo(session))
    case Saving{App.Document{destination, +session}, target, id, snapshot}:
      updated(True{}, value, Editor.redo(session))
    case Uncertain{App.Document{destination, +session}, target, id, snapshot}:
      updated(True{}, value, Editor.redo(session))

# Read the current document without discarding the outer transaction.
def document(value: Workspace) -> App.Document:
  match value:
    case Editing{document}:
      document
    case Saving{document, target, id, snapshot}:
      document
    case Uncertain{document, target, id, snapshot}:
      document

def edit_document(current: App.Document, value: Workspace, start: Nat, end: Nat, text: String) -> Workspace:
  match current:
    case App.Document{destination, session}:
      edit_finished(Editor.edit(session, start, end, text), value)

def edit(+value: Workspace, start: Nat, end: Nat, text: String) -> Workspace:
  edit_document(document(value), value, start, end, text)

def select_document(current: App.Document, value: Workspace, start: Nat, end: Nat) -> Workspace:
  match current:
    case App.Document{destination, session}:
      updated(True{}, value, Editor.select(session, start, end))

def select(+value: Workspace, start: Nat, end: Nat) -> Workspace:
  select_document(document(value), value, start, end)
