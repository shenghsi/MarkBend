import Base
import ./InitialOpen.bend as Initial
import ./AppDocument.bend as App
import ./RecoveryPlan.bend as Plan
import ./RecoveryScan.bend as Scan
import ./StoredRecovery.bend as Recovery

type Outcome is Data:
  Opened{document: App.Document, disk: List<&2, U32>, catalog: Scan.Catalog}
  Blocked{initial: Initial.Initial, plan: Plan.Plan}
  Unresolved{initial: Initial.Initial}

def applied(value: Recovery.Outcome, initial: Initial.Initial) -> Outcome:
  match value initial:
    case Recovery.Opened{requested, catalog, session}
      Initial.Initial{App.Document{destination, previous}, disk}:
      Opened{App.Document{destination, session}, disk, catalog}
    case Recovery.Blocked{plan} initial:
      Blocked{initial, plan}

# Use only the initial resolved read. This pure step makes no disk changes.
# A blocked plan retains the original document and the complete observation.
def prepare(+initial: Initial.Initial, catalog: Scan.Outcome) -> Outcome:
  match initial:
    case Initial.Initial{App.Document{App.Resolved{requested, path, identity}, session}, disk}:
      applied(Recovery.open(Plan.prepare(catalog, identity, disk)), initial)
    case _:
      Unresolved{initial}
