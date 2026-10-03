import Base
import ./AppSaveAs.bend as As
import ./NewFileReconcile.bend as Reconcile
import ./ByteBuffer.bend as Bytes

def observe_raw(path: String, identity: List<&2, U32>, parent: List<&2, U32>, bytes: List<&2, U32>) -> IO(U32):
  import "./new_file_observe.c"
  import "./new_file_observe.js"

def observation(code: U32) -> Reconcile.Observation:
  match code:
    case 0:
      Reconcile.ConfirmedObservation{}
    case _:
      Reconcile.RetainUncertain{}

def allowed(ok: Bool, +value: As.Workspace) -> IO(As.Workspace):
  match ok value:
    case True{} As.Uncertain{document, As.Target{requested, path, identity, parent}, +id, snapshot}:
      do IO<As.Workspace>:
        code : U32 <- observe_raw(path, identity, parent, Bytes.materialize(snapshot))
        return Reconcile.complete(value, id, observation(code))
    case _ value:
      IO.pure(As.Workspace, value)

def run(+value: As.Workspace) -> IO(As.Workspace):
  match value:
    case As.Uncertain{document, target, +id, snapshot}:
      allowed(As.matches(As.Saving{document, target, id, snapshot}, id), value)
    case value:
      IO.pure(As.Workspace, value)
