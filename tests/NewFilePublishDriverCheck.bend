import Base
import ../src/NewFilePublish.bend as Host
import ../src/NewFileTarget.bend as Target
import ../src/AppSaveAs.bend as As
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Flat
import ../src/AppSave.bend as Save
import ../src/ByteBuffer.bend as Bytes
import ../src/Utf8.bend as Utf8
import ./AppInputCheck.bend as Model
import ./StoredEditorCheck.bend as Stored
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def state() -> Flat.State:
  Flat.edit(Flat.open([65]), Encode.bytes(Utf8.encode(Model.text())))

def candidate(+path: String, mode: String) -> IO(As.Candidate):
  match mode:
    case "publication-unavailable":
      IO.pure(As.Candidate, As.Validated{As.Target{path, path,
        Encode.bytes(Utf8.encode("PATH1:" ++ path)), [68, 73, 82, 49, 58, 48, 58, 48]}})
    case _:
      Target.resolve(path)

def retained_target(value: As.Workspace, candidate: As.Candidate) -> Bool:
  match value candidate:
    case As.Uncertain{document, As.Target{requested, path, key, parent}, id, snapshot}
      As.Validated{As.Target{expected_request, expected_path, expected_key, expected_parent}}:
      String.eq(requested, expected_request) && String.eq(path, expected_path) &&
        Flat.bytes_equal(key, expected_key) && Flat.bytes_equal(parent, expected_parent)
    case _ _:
      True{}

def history(+session: Editor.Session, +state: Flat.State) -> Bool:
  Stored.matches(Editor.undo(session), "A", Flat.edit(state, [65])) &&
    Stored.matches(Editor.redo(Editor.undo(session)), Model.text(), state)

def completed_old(+session: Editor.Session) -> Bool:
  Stored.matches(session, Model.text(), Flat.complete(Flat.request(state()), 0n, Flat.OldKept{})) &&
    history(session, Flat.complete(Flat.request(state()), 0n, Flat.OldKept{}))

def checked(value: As.Workspace, +path: String, mode: String) -> Bool:
  match value mode:
    case As.Editing{App.Document{App.Resolved{requested, actual, key}, +session}} "save":
      String.eq(requested, path) && String.eq(actual, path) &&
        Flat.bytes_equal(key, Encode.bytes(Utf8.encode("PATH1:" ++ path))) &&
        Stored.matches(session, Model.text(), Flat.complete(Flat.request(state()), 0n, Flat.Confirmed{})) &&
        Stored.matches(Editor.undo(session), "A",
          Flat.edit(Flat.complete(Flat.request(state()), 0n, Flat.Confirmed{}), [65]))
    case As.Uncertain{App.Document{App.Untitled{}, +session}, As.Target{requested, actual, key, parent}, id, snapshot} "uncertain":
      String.eq(requested, path) && String.eq(actual, path) && Nat.is_eq(id, 0n) &&
        Flat.bytes_equal(Bytes.materialize(snapshot), Encode.bytes(Utf8.encode(Model.text()))) &&
        Stored.matches(session, Model.text(), Flat.request(state())) && history(session, Flat.request(state()))
    case As.Editing{App.Document{App.Untitled{}, +session}} "old":
      completed_old(session)
    case As.Editing{App.Document{App.Untitled{}, session}} "conflict":
      completed_old(session)
    case As.Editing{App.Document{App.Untitled{}, session}} "publication-unavailable":
      completed_old(session)
    case As.Editing{App.Document{App.Untitled{}, session}} "unavailable":
      Stored.matches(session, Model.text(), state())
    case _ _:
      False{}

def completion(value: Host.Completion, +mode: String) -> IO(As.Workspace):
  match value mode:
    case Host.Completed{workspace, Save.Confirmed{}} "save":
      IO.pure(As.Workspace, workspace)
    case Host.Completed{workspace, Save.OldKept{}} "old":
      IO.pure(As.Workspace, workspace)
    case Host.Completed{workspace, Save.Conflict{}} "conflict":
      IO.pure(As.Workspace, workspace)
    case Host.Completed{workspace, Save.Uncertain{}} "uncertain":
      IO.pure(As.Workspace, workspace)
    case Host.Completed{workspace, Save.UnavailableHost{}} "publication-unavailable":
      IO.pure(As.Workspace, workspace)
    case Host.NotStarted{workspace} "unavailable":
      IO.pure(As.Workspace, workspace)
    case _ _:
      IO.die(As.Workspace, 1, "Unexpected publication completion outcome")

def run(+path: String, +mode: String) -> IO(Unit):
  do IO<Unit>:
    initial : Editor.Session <- Stored.loaded(Editor.load(Flat.open([65])))
    edited : Editor.Session <- Stored.accepted(Editor.replace_source(initial, Model.text()))
    +candidate : As.Candidate <- candidate(path, mode)
    result_with_outcome : Host.Completion <- Host.run_completion(As.start(As.Editing{App.with_session(App.Untitled{}, edited)}, candidate))
    +result : As.Workspace <- completion(result_with_outcome, mode)
    Check.check(checked(result, path, mode))
    Check.check(retained_target(result, candidate))
    +repeated : As.Workspace <- Host.run(result)
    Check.check(checked(repeated, path, mode))
    Check.check(retained_target(repeated, candidate))
    IO.print("New-file publication driver completion passed")

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> path <> mode <> Nil{}:
      run(path, mode)
    case _:
      IO.die(Unit, 1, "Supply target path and expected driver result")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
