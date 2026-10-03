import Base
import ./AppSaveAs.bend as As
import ./AppSave.bend as Save
import ./DocumentSave.bend as Status
import ./ByteBuffer.bend as Bytes

type Completion is Data:
  Completed{workspace: As.Workspace, outcome: Save.Outcome}
  NotStarted{workspace: As.Workspace}

def publish_raw(path: String, identity: List<&2, U32>, parent: List<&2, U32>, bytes: List<&2, U32>) -> IO(U32):
  import "./new_file_publish.c"
  import "./new_file_publish.js"

def allowed(ok: Bool, +value: As.Workspace) -> IO(As.Workspace):
  match ok value:
    case True{} As.Saving{document, As.Target{requested, path, identity, parent}, +id, snapshot}:
      do IO<As.Workspace>:
        code : U32 <- publish_raw(path, identity, parent, Bytes.materialize(snapshot))
        return As.complete(value, id, Status.outcome(code))
    case _ value:
      IO.pure(As.Workspace, value)

# The synchronous driver owns the complete outer transaction during publication.
# Editing and uncertain transactions cannot start this host operation.
def run(+value: As.Workspace) -> IO(As.Workspace):
  match value:
    case As.Saving{document, target, +id, snapshot}:
      allowed(As.matches(value, id), value)
    case value:
      IO.pure(As.Workspace, value)

def completion_allowed(ok: Bool, +value: As.Workspace) -> IO(Completion):
  match ok value:
    case True{} As.Saving{document, As.Target{requested, path, identity, parent}, +id, snapshot}:
      do IO<Completion>:
        code : U32 <- publish_raw(path, identity, parent, Bytes.materialize(snapshot))
        +outcome : Save.Outcome = Status.outcome(code)
        return Completed{As.complete(value, id, outcome), outcome}
    case _ value:
      IO.pure(Completion, NotStarted{value})

def run_completion(+value: As.Workspace) -> IO(Completion):
  match value:
    case As.Saving{document, target, +id, snapshot}:
      completion_allowed(As.matches(value, id), value)
    case value:
      IO.pure(Completion, NotStarted{value})
