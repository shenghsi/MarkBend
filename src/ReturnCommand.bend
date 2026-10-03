import Base
import ./ListReturn.bend as Return
import ./IndexedReturn.bend as Indexed
import ./StoredEditor.bend as Stored
import ./DirectState.bend as State
import ./BlockScene.bend as Scene

type Prepared is Data:
  Prepared{edit: Return.Edit, result: Stored.EditResult}

type DirectPrepared is Data:
  DirectPrepared{edit: Return.Edit, session: State.Session}

def patches(editor: State.Session) -> List<&2, Scene.HostPatch>:
  match editor:
    case State.Session{current, undo, redo, State.RawView{scene, host, patches}, cache, index}:
      patches

# Patch coordinates refer to successive scenes. Keep both lists in order.
def with_prior(editor: State.Session, prior: List<&2, Scene.HostPatch>) -> State.Session:
  match editor:
    case State.Session{current, undo, redo, State.RawView{scene, host, edits}, cache, index}:
      State.Session{current, undo, redo, State.RawView{scene, host,
        List.reverse.go(&2, Scene.HostPatch, List.reverse(&2, Scene.HostPatch, prior), edits)}, cache, index}

def composed(result: Stored.EditResult, prior: List<&2, Scene.HostPatch>) -> Stored.EditResult:
  match result:
    case Stored.Accepted{Stored.Session{editor, storage}}:
      Stored.Accepted{Stored.Session{with_prior(editor, prior), storage}}
    case Stored.Rejected{session}:
      Stored.Rejected{session}

def planned(edit: Return.Edit, session: Stored.Session) -> Stored.EditResult:
  match edit:
    case Return.Edit{start, end, text}:
      Stored.edit_source(session, start, end, text)

def prepared(+edit: Return.Edit, session: Stored.Session,
  prior: List<&2, Scene.HostPatch>) -> Prepared:
  Prepared{edit, composed(planned(edit, session), prior)}

def selected(session: Stored.Session, snapshot: State.Snapshot,
  prior: List<&2, Scene.HostPatch>) -> Prepared:
  match snapshot:
    case State.Snapshot{start, end, document}:
      prepared(Indexed.plan(document, start, end), session, prior)

def selected_session(+session: Stored.Session) -> Prepared:
  match session:
    case Stored.Session{+editor, storage}:
      selected(session, State.current(editor), patches(editor))

def prepare(session: Stored.Session, start: Nat, end: Nat) -> Prepared:
  selected_session(Stored.select(session, start, end))

def result(prepared: Prepared) -> Stored.EditResult:
  match prepared:
    case Prepared{edit, result}:
      result

def command(session: Stored.Session, start: Nat, end: Nat) -> Stored.EditResult:
  result(prepare(session, start, end))

def direct_plan(edit: Return.Edit, session: State.Session) -> State.Session:
  match edit:
    case Return.Edit{start, end, text}:
      State.edit_source(session, start, end, text)

def direct_prepared(+edit: Return.Edit, session: State.Session,
  prior: List<&2, Scene.HostPatch>) -> DirectPrepared:
  DirectPrepared{edit, with_prior(direct_plan(edit, session), prior)}

def direct_snapshot(session: State.Session, snapshot: State.Snapshot,
  prior: List<&2, Scene.HostPatch>) -> DirectPrepared:
  match snapshot:
    case State.Snapshot{start, end, document}:
      direct_prepared(Indexed.plan(document, start, end), session, prior)

def direct_selected(+session: State.Session) -> DirectPrepared:
  direct_snapshot(session, State.current(session), patches(session))

def prepare_direct(session: State.Session, start: Nat, end: Nat) -> DirectPrepared:
  direct_selected(State.select(session, start, end))

def direct_result(prepared: DirectPrepared) -> State.Session:
  match prepared:
    case DirectPrepared{edit, session}:
      session

def direct(session: State.Session, start: Nat, end: Nat) -> State.Session:
  direct_result(prepare_direct(session, start, end))
