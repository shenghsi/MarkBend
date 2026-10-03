import Base
import ./ResolvedOpen.bend as Resolved
import ./AppDocument.bend as App

# This value belongs to startup. Keep the actual read bytes, not a later
# session's saved baseline. It grants no save permission.
type Initial is Data:
  Initial{document: App.Document, disk: List<&2, U32>}

type Outcome is Data:
  Opened{initial: Initial}
  Failed{reason: Resolved.Outcome}

def decoded(value: Resolved.Outcome, disk: List<&2, U32>) -> Outcome:
  match value:
    case Resolved.Opened{document}:
      Opened{Initial{document, disk}}
    case reason:
      Failed{reason}

def decode(+raw: Resolved.Raw) -> Outcome:
  match raw:
    case Resolved.Raw{requested, path, identity, bytes}:
      decoded(Resolved.decode(raw), bytes)

def received(value: Result<&1, &1, U32 & String,
  List<&2, U32> & (List<&2, U32> & List<&2, U32>)>, requested: String) -> Outcome:
  match value:
    case Fail{(code, message)}:
      Failed{Resolved.ReadFailed{requested, code, message}}
    case Done{(path, (identity, bytes))}:
      decode(Resolved.Raw{requested, path, identity, bytes})
