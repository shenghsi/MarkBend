import Base
import ./AppSaveAs.bend as As
import ./AppSave.bend as Save

# A host may confirm only after reading the captured bytes, synchronizing the
# file and recorded parent, and checking the observation again. It never writes.
type Observation is Data:
  ConfirmedObservation{}
  RetainUncertain{}

def matched(ok: Bool, value: As.Workspace) -> As.Workspace:
  match ok value:
    case True{} As.Uncertain{document, target, +id, snapshot}:
      As.complete(As.Saving{document, target, id, snapshot}, id, Save.Confirmed{})
    case _ value:
      value

def complete(+value: As.Workspace, id: Nat, observation: Observation) -> As.Workspace:
  match value observation:
    case As.Uncertain{document, target, active, snapshot} ConfirmedObservation{}:
      matched(As.matches(As.Saving{document, target, active, snapshot}, id), value)
    case value _:
      value
