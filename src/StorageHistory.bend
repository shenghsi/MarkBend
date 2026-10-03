import Base
import ./TextStorage.bend as Text
import ./PersistentSave.bend as Save
import ./SaveState.bend as Flat

type Revision is Data:
  Revision{snapshot: Text.Snapshot, id: Nat}

# Identifiers are local to one session. Undo does not reset the next identifier.
# Never compare identifiers from different sessions or load them from records.
type Identity is Data:
  Identity{next: Nat, current: Nat, saved: Maybe<&2, Nat>, pending: Maybe<&2, Nat>}

type Session is Data:
  Session{current: Text.Snapshot, undo: List<&2, Revision>,
    redo: List<&2, Revision>, save: Save.State, identity: Identity}

type EditResult is Data:
  Accepted{session: Session}
  Rejected{session: Session}

def saved_identity(clean: Bool) -> Maybe<&2, Nat>:
  match clean:
    case True{}:
      Some{0n}
    case False{}:
      None{}

def opened(snapshot: Text.Snapshot, +save: Save.State) -> Session:
  Session{snapshot, Nil{}, Nil{}, save,
    Identity{1n, 0n, saved_identity(Bool.not(Save.dirty(save))), None{}}}

# A recovered current snapshot must be valid UTF-8. Saved and pending bytes
# remain raw bytes. Opening starts fresh history and retains the save fields.
def load(+state: Flat.State) -> Maybe<&2, Session>:
  match state:
    case Flat.State{current, saved, next, pending}:
      do Maybe<&2, Session>:
        snapshot : Text.Snapshot <- Text.from_bytes(current)
        save : Save.State <- Save.load(state)
        return opened(snapshot, save)

def sync(save: Save.State, snapshot: Text.Snapshot) -> Save.State:
  match snapshot:
    case Text.Snapshot{bytes, mapping}:
      Save.edit(save, bytes)

def edited(value: Text.EditResult, original: Session) -> EditResult:
  match value original:
    case Text.Accepted{+snapshot} Session{current, undo, redo, save,
      Identity{+next, current_id, saved, pending}}:
      Accepted{Session{snapshot, Revision{current, current_id} <> undo, Nil{}, sync(save, snapshot),
        Identity{1n+next, next, saved, pending}}}
    case Text.Rejected{snapshot} original:
      Rejected{original}

def edit(+session: Session, start: Nat, end: Nat, text: String) -> EditResult:
  match session:
    case Session{current, undo, redo, save, identity}:
      edited(Text.replace(current, start, end, text), session)

def replaced(value: Maybe<&2, Text.Snapshot>, original: Session) -> EditResult:
  match value:
    case Some{snapshot}:
      edited(Text.Accepted{snapshot}, original)
    case None{}:
      Rejected{original}

def replace_source(session: Session, text: String) -> EditResult:
  replaced(Text.from_text(text), session)

def undo(session: Session) -> Session:
  match session:
    case Session{current, Nil{}, redo, save, identity}:
      Session{current, Nil{}, redo, save, identity}
    case Session{current, Revision{+previous, previous_id} <> rest, redo, save,
      Identity{next, current_id, saved, pending}}:
      Session{previous, rest, Revision{current, current_id} <> redo, sync(save, previous),
        Identity{next, previous_id, saved, pending}}

def redo(session: Session) -> Session:
  match session:
    case Session{current, undo, Nil{}, save, identity}:
      Session{current, undo, Nil{}, save, identity}
    case Session{current, undo, Revision{+snapshot, snapshot_id} <> rest, save,
      Identity{next, current_id, saved, pending}}:
      Session{snapshot, Revision{current, current_id} <> undo, rest, sync(save, snapshot),
        Identity{next, snapshot_id, saved, pending}}

def request(session: Session) -> Session:
  match session:
    case Session{current, undo, redo, Save.State{+bytes, baseline, +ticket_id, None{}},
      Identity{next, +current_id, saved, pending}}:
      Session{current, undo, redo,
        Save.State{bytes, baseline, 1n+ticket_id, Some{Save.Ticket{ticket_id, bytes}}},
        Identity{next, current_id, saved, Some{current_id}}}
    case session:
      session

def completed_identity(same: Bool, outcome: Flat.Outcome, identity: Identity) -> Identity:
  match same outcome identity:
    case True{} Flat.Confirmed{} Identity{next, current, saved, pending}:
      Identity{next, current, pending, None{}}
    case True{} Flat.OldKept{} Identity{next, current, saved, pending}:
      Identity{next, current, saved, None{}}
    case _ _ identity:
      identity

def result_identity(save: Save.State, id: Nat, outcome: Flat.Outcome, identity: Identity) -> Identity:
  match save:
    case Save.State{bytes, baseline, next, Some{Save.Ticket{ticket_id, pending}}}:
      completed_identity(Nat.is_eq(id, ticket_id), outcome, identity)
    case _:
      identity

def complete(session: Session, +id: Nat, +outcome: Flat.Outcome) -> Session:
  match session:
    case Session{current, undo, redo, +save, identity}:
      Session{current, undo, redo, Save.complete(save, id, outcome),
        result_identity(save, id, outcome, identity)}

def known_dirty(same: Bool, save: Save.State) -> Bool:
  match same:
    case True{}:
      False{}
    case False{}:
      Save.dirty(save)

def dirty(session: Session) -> Bool:
  match session:
    case Session{current, undo, redo, save, Identity{next, current_id, Some{saved_id}, pending}}:
      known_dirty(Nat.is_eq(current_id, saved_id), save)
    case Session{current, undo, redo, save, identity}:
      Save.dirty(save)

def clear_history(session: Session) -> Session:
  match session:
    case Session{current, undo, redo, save, identity}:
      Session{current, Nil{}, Nil{}, save, identity}
