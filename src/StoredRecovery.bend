import Base
import ./RecoveryPlan.bend as Plan
import ./RecoveryScan.bend as Scan
import ./RecoveryEntry.bend as Entry
import ./RecoveryState.bend as Recovery
import ./SaveState.bend as Save
import ./StoredEditor.bend as Editor

type Outcome is Data:
  Opened{requested: List<&2, U32>, catalog: Scan.Catalog, editor: Editor.Session}
  Blocked{plan: Plan.Plan}

def loaded(value: Maybe<&2, Editor.Session>, plan: Plan.Plan,
  requested: List<&2, U32>, catalog: Scan.Catalog) -> Outcome:
  match value:
    case Some{editor}:
      Opened{requested, catalog, editor}
    case None{}:
      Blocked{plan}

# Use the same recovery permission boundary as RecoveryEditor. Keep the full
# plan on failure; do not write files or replace an existing session here.
def open(+plan: Plan.Plan) -> Outcome:
  match plan:
    case Plan.Plan{requested, Plan.NoMatch{catalog, disk}}:
      loaded(Editor.load(Save.open(disk)), plan, requested, catalog)
    case Plan.Plan{requested, Plan.Ready{catalog,
      Entry.ForDocument{Recovery.Restored{save}}}}:
      loaded(Editor.load(save), plan, requested, catalog)
    case _:
      Blocked{plan}
