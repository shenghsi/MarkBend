import Base
import ./SaveState.bend as Save

type Decision is Data:
  Restored{state: Save.State}
  Conflict{recorded: Save.State, disk: List<&2, U32>}

def pending_matches(pending: Maybe<&2, Save.Ticket>, disk: List<&2, U32>) -> Bool:
  match pending:
    case None{}:
      False{}
    case Some{Save.Ticket{id, bytes}}:
      Save.bytes_equal(bytes, disk)

def restore_known(known: Bool, recorded: Save.State, disk: List<&2, U32>) -> Decision:
  match known:
    case False{}:
      Conflict{recorded, disk}
    case True{}:
      match recorded:
        case Save.State{current, saved, next, pending}:
          Restored{Save.State{current, disk, next, None{}}}

# The caller must validate the recovery record and obtain a stable disk read.
# No interrupted request is restarted by this pure recovery step.
def recover(+recorded: Save.State, +disk: List<&2, U32>) -> Decision:
  match recorded:
    case Save.State{current, saved, next, pending}:
      restore_known(Save.bytes_equal(saved, disk) || pending_matches(pending, disk), recorded, disk)
