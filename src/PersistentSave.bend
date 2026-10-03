import Base
import ./ByteBuffer.bend as Bytes
import ./SaveState.bend as Save
import ./RecoveryRecord.bend as Record

# Raw bytes remain valid save snapshots even if they are not editable UTF-8.
type Ticket is Data:
  Ticket{id: Nat, bytes: Bytes.Buffer}

type State is Data:
  State{current: Bytes.Buffer, saved: Bytes.Buffer, next: Nat,
    pending: Maybe<&2, Ticket>}

def load_pending(value: Maybe<&2, Save.Ticket>) -> Maybe<&2, Maybe<&2, Ticket>>:
  match value:
    case None{}:
      Some{None{}}
    case Some{Save.Ticket{id, bytes}}:
      do Maybe<&2, Maybe<&2, Ticket>>:
        buffer : Bytes.Buffer <- Bytes.from_bytes(bytes)
        return Some{Ticket{id, buffer}}

def load(state: Save.State) -> Maybe<&2, State>:
  match state:
    case Save.State{current, saved, next, pending}:
      do Maybe<&2, State>:
        current : Bytes.Buffer <- Bytes.from_bytes(current)
        saved : Bytes.Buffer <- Bytes.from_bytes(saved)
        pending : Maybe<&2, Ticket> <- load_pending(pending)
        return State{current, saved, next, pending}

def flat_pending(value: Maybe<&2, Ticket>) -> Maybe<&2, Save.Ticket>:
  match value:
    case None{}:
      None{}
    case Some{Ticket{id, bytes}}:
      Some{Save.Ticket{id, Bytes.materialize(bytes)}}

# Flatten at effect and record boundaries, not on each edit or save request.
def materialize(state: State) -> Save.State:
  match state:
    case State{current, saved, next, pending}:
      Save.State{Bytes.materialize(current), Bytes.materialize(saved), next,
        flat_pending(pending)}

# Record serialization is an explicit boundary that requires flat bytes.
def encode_record(state: State) -> Maybe<&2, String>:
  Record.encode(materialize(state))

def decode_record(text: String) -> Maybe<&2, State>:
  do Maybe<&2, State>:
    state : Save.State <- Record.decode(text)
    load(state)

def edit(state: State, bytes: Bytes.Buffer) -> State:
  match state:
    case State{current, saved, next, pending}:
      State{bytes, saved, next, pending}

def request(state: State) -> State:
  match state:
    case State{+current, saved, +next, None{}}:
      State{current, saved, 1n+next, Some{Ticket{next, current}}}
    case state:
      state

def accept(ok: Bool, current: Bytes.Buffer, saved: Bytes.Buffer,
  next: Nat, bytes: Bytes.Buffer) -> State:
  match ok:
    case True{}:
      State{current, bytes, next, None{}}
    case False{}:
      State{current, saved, next, None{}}

def result_matches(same: Bool, ok: Bool, current: Bytes.Buffer,
  saved: Bytes.Buffer, next: Nat, ticket: Ticket) -> State:
  match same ticket:
    case True{} Ticket{id, bytes}:
      accept(ok, current, saved, next, bytes)
    case False{} ticket:
      State{current, saved, next, Some{ticket}}

def result(state: State, id: Nat, ok: Bool) -> State:
  match state:
    case State{current, saved, next, None{}}:
      State{current, saved, next, None{}}
    case State{current, saved, next, Some{+ticket}}:
      match ticket:
        case Ticket{ticket_id, bytes}:
          result_matches(Nat.is_eq(id, ticket_id), ok, current, saved, next, ticket)

def complete(state: State, id: Nat, outcome: Save.Outcome) -> State:
  match outcome:
    case Save.OldKept{}:
      result(state, id, False{})
    case Save.ReplacementUncertain{}:
      state
    case Save.Confirmed{}:
      result(state, id, True{})

def reconcile_equal(new: Bool, old: Bool, state: State, id: Nat) -> State:
  match new old:
    case True{} _:
      result(state, id, True{})
    case False{} True{}:
      result(state, id, False{})
    case False{} False{}:
      state

# The caller supplies a stable observation and confirms file/directory sync.
def reconcile_synced(synced: Bool, state: State, id: Nat, +observed: Bytes.Buffer) -> State:
  match synced state:
    case False{} state:
      state
    case True{} State{current, saved, next, None{}}:
      State{current, saved, next, None{}}
    case True{} State{current, +saved, next, Some{Ticket{ticket_id, +bytes}}}:
      new old = Bytes.equal(observed, bytes) Bytes.equal(observed, saved)
      reconcile_equal(new, old,
        State{current, saved, next, Some{Ticket{ticket_id, bytes}}}, id)

def reconcile(state: State, id: Nat, observed: Bytes.Buffer, synced: Bool) -> State:
  reconcile_synced(synced, state, id, observed)

def dirty(state: State) -> Bool:
  match state:
    case State{current, saved, next, pending}:
      Bool.not(Bytes.equal(current, saved))
