import Base
import ./RecoveryScan.bend as Scan
import ./RecoveryLookup.bend as Lookup
import ./RecoveryEntry.bend as Entry

type Decision is Data:
  NoMatch{catalog: Scan.Catalog, disk: List<&2, U32>}
  Ready{catalog: Scan.Catalog, recovery: Entry.Decision}
  Review{catalog: Scan.Catalog, selection: Lookup.Selection, disk: List<&2, U32>}
  Unavailable{root: String, reason: Scan.Failure, disk: List<&2, U32>}

type Plan is Data:
  Plan{requested: List<&2, U32>, decision: Decision}

def clean(catalog: Scan.Catalog) -> Bool:
  match catalog:
    case Scan.Catalog{accepted, Nil{}}:
      True{}
    case _:
      False{}

def selected(complete: Bool, catalog: Scan.Catalog, selection: Lookup.Selection,
  requested: List<&2, U32>, disk: List<&2, U32>) -> Decision:
  match complete selection:
    case True{} Lookup.Missing{}:
      NoMatch{catalog, disk}
    case True{} Lookup.Unique{entry}:
      Ready{catalog, Entry.recover(requested, entry, disk)}
    case _ _:
      Review{catalog, selection, disk}

# The caller supplies validated scan results and a stable source-file read.
# A rejected entry can hide another owner. Do not infer absence or unique
# ownership until the caller has reviewed every rejected entry. This function
# makes no file writes and does not apply a recovery decision to the editor.
def decision(outcome: Scan.Outcome, +requested: List<&2, U32>,
  disk: List<&2, U32>) -> Decision:
  match outcome:
    case Scan.Completed{+catalog}:
      selected(clean(catalog), catalog,
        Lookup.lookup(Scan.entries(catalog), requested), requested, disk)
    case Scan.Failed{root, reason}:
      Unavailable{root, reason, disk}

def prepare(outcome: Scan.Outcome, +requested: List<&2, U32>,
  disk: List<&2, U32>) -> Plan:
  Plan{requested, decision(outcome, requested, disk)}
