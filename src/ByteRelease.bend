import Base
import ./ByteBuffer.bend as Bytes
import ./BlockIndex.bend as Index

type Queue is Data:
  Queue{trees: List<&2, Index.Tree<Bytes.Chunk>>}

type Progress is Data:
  Complete{}
  Pending{queue: Queue}

def begin(buffer: Bytes.Buffer) -> Queue:
  match buffer:
    case Bytes.Buffer{tree}:
      Queue{[tree]}

# Each step opens at most one tree node. A valid leaf holds at most 512 bytes.
# Consume the queue; do not retain old queues or drop a pending queue in the UI.
def step(fuel: Nat, queue: Queue) -> Progress:
  match fuel queue:
    case _ Queue{Nil{}}:
      Complete{}
    case 0n queue:
      Pending{queue}
    case 1n+remaining Queue{Index.Empty{} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{Index.Leaf{chunk, size} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{Index.Branch{left, right, size, count, height} <> rest}:
      step(remaining, Queue{left <> right <> rest})
