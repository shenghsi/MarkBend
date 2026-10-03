import Base

# Bytes are snapshots. A host result names the request that wrote those bytes.
type Ticket is Data:
  Ticket{id: Nat, bytes: List<&2, U32>}

type Outcome is Data:
  OldKept{}
  ReplacementUncertain{}
  Confirmed{}

type State is Data:
  State{current: List<&2, U32>, saved: List<&2, U32>, next: Nat,
    pending: Maybe<&2, Ticket>}

def open(+bytes: List<&2, U32>) -> State:
  State{bytes, bytes, 0n, None{}}

def edit(state: State, bytes: List<&2, U32>) -> State:
  match state:
    case State{current, saved, next, pending}:
      State{bytes, saved, next, pending}

def request(state: State) -> State:
  match state:
    case State{+current, saved, +next, None{}}:
      State{current, saved, 1n+next, Some{Ticket{next, current}}}
    case State{current, saved, next, Some{ticket}}:
      State{current, saved, next, Some{ticket}}

def accept(ok: Bool, current: List<&2, U32>, saved: List<&2, U32>,
  next: Nat, bytes: List<&2, U32>) -> State:
  match ok:
    case True{}:
      State{current, bytes, next, None{}}
    case False{}:
      State{current, saved, next, None{}}

def result_matches(same: Bool, ok: Bool, current: List<&2, U32>,
  saved: List<&2, U32>, next: Nat, ticket: Ticket) -> State:
  match same ticket:
    case True{} Ticket{id, bytes}:
      accept(ok, current, saved, next, bytes)
    case False{} ticket:
      State{current, saved, next, Some{ticket}}

# True confirms replacement and parent-directory sync. False confirms no
# replacement. Use complete for an uncertain host result.
def result(state: State, id: Nat, ok: Bool) -> State:
  match state:
    case State{current, saved, next, None{}}:
      State{current, saved, next, None{}}
    case State{current, saved, next, Some{+ticket}}:
      match ticket:
        case Ticket{ticket_id, bytes}:
          result_matches(Nat.is_eq(id, ticket_id), ok, current, saved, next, ticket)

# Uncertain replacement keeps the pending ticket. Do not start another writer
# until the host reconciles the destination and reports a definite outcome.
def complete(state: State, id: Nat, outcome: Outcome) -> State:
  match outcome:
    case OldKept{}:
      result(state, id, False{})
    case ReplacementUncertain{}:
      state
    case Confirmed{}:
      result(state, id, True{})

def bytes_equal_go(left: List<&2, U32>, right: List<&2, U32>, ok: Bool) -> Bool:
  match left right ok:
    case Nil{} Nil{} True{}:
      True{}
    case Con{x, xs} Con{y, ys} True{}:
      bytes_equal_go(xs, ys, U32.is_eq(x, y))
    case _ _ _:
      False{}

def bytes_equal(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  bytes_equal_go(a, b, True{})

def reconcile_equal(new: Bool, old: Bool, state: State, id: Nat) -> State:
  match new old:
    case True{} _:
      result(state, id, True{})
    case False{} True{}:
      result(state, id, False{})
    case False{} False{}:
      state

# The host must supply a stable byte observation and confirm file/directory
# sync. This function does not read the disk or exclude concurrent writers.
def reconcile(state: State, id: Nat, +observed: List<&2, U32>, synced: Bool) -> State:
  match state synced:
    case state False{}:
      state
    case State{current, saved, next, None{}} True{}:
      State{current, saved, next, None{}}
    case State{current, +saved, next, Some{Ticket{ticket_id, +bytes}}} True{}:
      reconcile_equal(bytes_equal(observed, bytes), bytes_equal(observed, saved),
        State{current, saved, next, Some{Ticket{ticket_id, bytes}}}, id)

def dirty(state: State) -> Bool:
  match state:
    case State{current, saved, next, pending}:
      Bool.not(bytes_equal(current, saved))
