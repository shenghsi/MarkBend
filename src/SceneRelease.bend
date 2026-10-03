import Base
import ./DirectState.bend as Editor
import ./Document.bend as Document
import ./BlockIndex.bend as Index
import ./BlockScene.bend as Scene
import ./BlockSceneCache.bend as Cache
import ./SceneIndex.bend as Mapping

type Item is Data:
  EditorSession{session: Editor.Session}
  Snapshot{snapshot: Editor.Snapshot}
  Snapshots{values: List<&2, Editor.Snapshot>}
  Documents{tree: Index.Tree<Document.Block>}
  CacheTree{tree: Cache.Trie}
  CacheEntry{entry: Maybe<&2, Cache.Entry>}
  SceneValue{scene: Scene.Scene}
  SceneTree{tree: Mapping.Tree}
  SceneChunk{chunk: Mapping.Chunk}
  Runs{values: List<&2, Scene.Run>}
  Chunks{values: List<&2, Scene.HostChunk>}
  Patches{values: List<&2, Scene.HostPatch>}
  Text{text: String}
  Points{values: List<&2, Nat>}

type Queue is Data:
  Queue{items: List<&2, Item>}

type Progress is Data:
  Complete{}
  Pending{queue: Queue}

def begin(session: Editor.Session) -> Queue:
  Queue{[EditorSession{session}]}

def drop_text(fuel: Nat, text: String) -> String:
  match fuel text:
    case 0n text:
      text
    case 1n+remaining SCon{char, rest}:
      drop_text(remaining, rest)
    case _ SNil{}:
      SNil{}

def drop_points(fuel: Nat, points: List<&2, Nat>) -> List<&2, Nat>:
  match fuel points:
    case 0n points:
      points
    case 1n+remaining point <> rest:
      drop_points(remaining, rest)
    case _ Nil{}:
      Nil{}

def text_queue(text: String, rest: List<&2, Item>) -> Queue:
  match text:
    case SNil{}:
      Queue{rest}
    case text:
      Queue{Text{text} <> rest}

def points_queue(points: List<&2, Nat>, rest: List<&2, Item>) -> Queue:
  match points:
    case Nil{}:
      Queue{rest}
    case points:
      Queue{Points{points} <> rest}

# Each item opens one container, or consumes at most 128 scalars/points.
# Document blocks and scene runs can be large; never drop their text directly.
def step(fuel: Nat, queue: Queue) -> Progress:
  match fuel queue:
    case _ Queue{Nil{}}:
      Complete{}
    case 0n queue:
      Pending{queue}
    case 1n+remaining Queue{EditorSession{Editor.Session{current, undo, redo,
      Editor.RawView{scene, host, patches}, Cache.Cache{tree, count, rebuilt, reused}, index}} <> rest}:
      step(remaining, Queue{Snapshot{current} <> Snapshots{undo} <> Snapshots{redo} <>
        SceneValue{scene} <> Chunks{host} <> Patches{patches} <> CacheTree{tree} <> SceneTree{index} <> rest})
    case 1n+remaining Queue{Snapshot{Editor.Snapshot{start, end,
      Document.Document{blocks, next, reparsed}}} <> rest}:
      step(remaining, Queue{Documents{blocks} <> rest})
    case 1n+remaining Queue{Snapshots{Nil{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{Snapshots{snapshot <> values} <> rest}:
      step(remaining, Queue{Snapshot{snapshot} <> Snapshots{values} <> rest})
    case 1n+remaining Queue{Documents{Index.Empty{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{Documents{Index.Leaf{Document.Block{id, kind, source}, length}} <> rest}:
      step(remaining, Queue{Text{source} <> rest})
    case 1n+remaining Queue{Documents{Index.Branch{left, right, length, count, height}} <> rest}:
      step(remaining, Queue{Documents{left} <> Documents{right} <> rest})
    case 1n+remaining Queue{CacheTree{Cache.Empty{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{CacheTree{Cache.Node{item, zero, one}} <> rest}:
      step(remaining, Queue{CacheEntry{item} <> CacheTree{zero} <> CacheTree{one} <> rest})
    case 1n+remaining Queue{CacheEntry{None{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{CacheEntry{Some{Cache.Entry{id, start, end, scene, chunk}}} <> rest}:
      step(remaining, Queue{SceneValue{scene} <> SceneChunk{chunk} <> rest})
    case 1n+remaining Queue{SceneValue{Scene.Scene{runs, points}} <> rest}:
      step(remaining, Queue{Runs{runs} <> Points{points} <> rest})
    case 1n+remaining Queue{SceneTree{Mapping.Empty{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{SceneTree{Mapping.Leaf{chunk}} <> rest}:
      step(remaining, Queue{SceneChunk{chunk} <> rest})
    case 1n+remaining Queue{SceneTree{Mapping.Branch{left, right, source, native, last, count, height}} <> rest}:
      step(remaining, Queue{SceneTree{left} <> SceneTree{right} <> rest})
    case 1n+remaining Queue{SceneChunk{Mapping.Chunk{visible, points, source, native, last, id, start, end, runs}} <> rest}:
      step(remaining, Queue{Text{visible} <> Points{points} <> Runs{runs} <> rest})
    case 1n+remaining Queue{Runs{Nil{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{Runs{Scene.Run{text, style} <> values} <> rest}:
      step(remaining, Queue{Text{text} <> Runs{values} <> rest})
    case 1n+remaining Queue{Chunks{Nil{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{Chunks{Scene.HostChunk{id, fresh, runs} <> values} <> rest}:
      step(remaining, Queue{Runs{runs} <> Chunks{values} <> rest})
    case 1n+remaining Queue{Patches{Nil{}} <> rest}:
      step(remaining, Queue{rest})
    case 1n+remaining Queue{Patches{Scene.HostPatch{first, removed, start, length, chunks} <> values} <> rest}:
      step(remaining, Queue{Chunks{chunks} <> Patches{values} <> rest})
    case 1n+remaining Queue{Text{text} <> rest}:
      step(remaining, text_queue(drop_text(128n, text), rest))
    case 1n+remaining Queue{Points{points} <> rest}:
      step(remaining, points_queue(drop_points(128n, points), rest))
