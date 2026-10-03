import Base
import ./TextStorage.bend as Text
import ./TextByteMap.bend as Mapping
import ./BlockIndex.bend as Index
import ./ByteRelease.bend as Bytes
import ./StorageHistory.bend as History
import ./PersistentSave.bend as Save

type Item is Data:
  Snapshot{snapshot: Text.Snapshot}
  ByteQueue{queue: Bytes.Queue}
  Spans{tree: Index.Tree<Mapping.Span>}
  HistorySession{session: History.Session}
  Revisions{values: List<&2, History.Revision>}
  SaveState{state: Save.State}
  PendingTicket{ticket: Maybe<&2, Save.Ticket>}

type Queue is Data:
  Queue{items: List<&2, Item>}

type Progress is Data:
  Complete{}
  Pending{queue: Queue}

def begin(snapshot: Text.Snapshot) -> Queue:
  Queue{[Snapshot{snapshot}]}

def begin_history(session: History.Session) -> Queue:
  Queue{[HistorySession{session}]}

def byte_progress(value: Bytes.Progress, rest: List<&2, Item>) -> Queue:
  match value:
    case Bytes.Complete{}:
      Queue{rest}
    case Bytes.Pending{queue}:
      Queue{ByteQueue{queue} <> rest}

# Valid byte leaves hold at most 512 bytes; valid map spans hold at most 128
# scalars. Both paired map roots must be queued, even if they share spans.
def step(fuel: Nat, queue: Queue) -> Progress:
  match fuel queue:
    case _ Queue{Nil{}}:
      Complete{}
    case 0n queue:
      Pending{queue}
    case 1n+remaining Queue{HistorySession{History.Session{current, undo, redo, save, identity}} <> rest}:
      step(remaining, Queue{Snapshot{current} <> Revisions{undo} <> Revisions{redo} <> SaveState{save} <> rest})
    case 1n+remaining Queue{Revisions{Nil{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{Revisions{History.Revision{snapshot, id} <> values} <> rest}:
      step(remaining, Queue{Snapshot{snapshot} <> Revisions{values} <> rest})
    case 1n+remaining Queue{SaveState{Save.State{current, saved, next, pending}} <> rest}:
      step(remaining, Queue{ByteQueue{Bytes.begin(current)} <> ByteQueue{Bytes.begin(saved)} <>
        PendingTicket{pending} <> rest})
    case 1n+remaining Queue{PendingTicket{None{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{PendingTicket{Some{Save.Ticket{id, bytes}}} <> rest}:
      step(remaining, Queue{ByteQueue{Bytes.begin(bytes)} <> rest})
    case 1n+remaining Queue{Snapshot{Text.Snapshot{bytes,
      Mapping.Mapping{scalars, utf8}}} <> rest}:
      step(remaining, Queue{ByteQueue{Bytes.begin(bytes)} <> Spans{scalars} <> Spans{utf8} <> rest})
    case 1n+remaining Queue{ByteQueue{queue} <> rest}:
      step(remaining, byte_progress(Bytes.step(1n, queue), rest))
    case 1n+remaining Queue{Spans{Index.Empty{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{Spans{Index.Leaf{span, length}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{Spans{Index.Branch{left, right, length, count, height}} <> rest}:
      step(remaining, Queue{Spans{left} <> Spans{right} <> rest})
