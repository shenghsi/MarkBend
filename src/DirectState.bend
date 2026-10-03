import Base
import ./BlockScene.bend as Scene
import ./Document.bend as D
import ./BlockSceneCache.bend as Cache
import ./SceneIndex.bend as Mapping
import ./BlockIndex.bend as Index

type Snapshot is Data:
  Snapshot{start: Nat, end: Nat, document: D.Document}

# The source-preserving document tree is the snapshot's only text storage.
def document_source(document: D.Document) -> String:
  match document:
    case D.Document{blocks, next, reparsed}:
      D.source(blocks)

def document_length(document: D.Document) -> Nat:
  match document:
    case D.Document{blocks, next, reparsed}:
      Index.length(D.Block, blocks)

def source(snapshot: Snapshot) -> String:
  match snapshot:
    case Snapshot{start, end, document}:
      document_source(document)

def source_length(snapshot: Snapshot) -> Nat:
  match snapshot:
    case Snapshot{start, end, document}:
      document_length(document)

type View is Data:
  View{scene: Scene.Scene, visible: String}

type RawView is Data:
  RawView{scene: Scene.Scene, host: List<&2, Scene.HostChunk>, patches: List<&2, Scene.HostPatch>}

type Session is Data:
  Session{current: Snapshot, undo: List<&2, Snapshot>, redo: List<&2, Snapshot>, view: RawView,
    cache: Cache.Cache, index: Mapping.Tree}

# Keep the current projection and block cache outside history snapshots.
def cached_session(snapshot: Snapshot, undo: List<&2, Snapshot>, redo: List<&2, Snapshot>,
  result: Cache.CachedScene) -> Session:
  match result:
    case Cache.CachedScene{scene, cache, index, host, patches}:
      Session{snapshot, undo, redo, RawView{scene, host, patches}, cache, index}

def create_cached(+snapshot: Snapshot, undo: List<&2, Snapshot>, redo: List<&2, Snapshot>,
  cache: Cache.Cache, prior: Mapping.Tree) -> Session:
  match snapshot:
    case Snapshot{start, end, document}:
      cached_session(snapshot, undo, redo, Cache.render_with_index(document, start, end, cache, prior))

def create(+snapshot: Snapshot, undo: List<&2, Snapshot>, redo: List<&2, Snapshot>) -> Session:
  create_cached(snapshot, undo, redo, Cache.empty(), Mapping.Empty{})

def start(source: String) -> Session:
  create(Snapshot{0n, 0n, D.parse(source)}, Nil{}, Nil{})

def current(session: Session) -> Snapshot:
  match session:
    case Session{snapshot, undo, redo, view, cache, index}:
      snapshot

def clear_history(session: Session) -> Session:
  match session:
    case Session{snapshot, undo, redo, view, cache, index}:
      Session{snapshot, Nil{}, Nil{}, view, cache, index}

def raw_view(session: Session) -> RawView:
  match session:
    case Session{snapshot, undo, redo, view, cache, index}:
      view

def full_view(view: RawView, +index: Mapping.Tree) -> View:
  match view:
    case RawView{scene, host, patches}:
      +complete : Scene.Scene = Scene.Scene{Mapping.runs(index, Nil{}), Nil{}}
      View{Mapping.full_scene(complete, index), Scene.text(complete)}

# The complete map is for reference checks. The live path uses raw_view/index.
def view(session: Session) -> View:
  match session:
    case Session{snapshot, undo, redo, view, cache, index}:
      full_view(view, index)

def cache(session: Session) -> Cache.Cache:
  match session:
    case Session{snapshot, undo, redo, view, cache, index}:
      cache

def index(session: Session) -> Mapping.Tree:
  match session:
    case Session{snapshot, undo, redo, view, cache, index}:
      index

def source_selection(collapsed: Bool, +index: Mapping.Tree,
  +native_start: Nat, native_end: Nat) -> Nat & Nat:
  match collapsed:
    case True{}:
      +point = Mapping.to_source(index, native_start)
      (point, point)
    case False{}:
      (Mapping.to_source(index, native_start), Mapping.to_source(index, native_end))

def selected_snapshot(document: D.Document, selection: Nat & Nat) -> Snapshot:
  match selection:
    case (a, b):
      Snapshot{a, b, document}

def select_snapshot(snapshot: Snapshot, index: Mapping.Tree, +native_start: Nat, +native_end: Nat) -> Snapshot:
  match snapshot:
    case Snapshot{start, end, document}:
      selected_snapshot(document,
        source_selection(Nat.is_eq(native_start, native_end), index,
          native_start, native_end))

def select_cached(+next: Snapshot, previous: Snapshot,
  undo: List<&2, Snapshot>, redo: List<&2, Snapshot>, cache: Cache.Cache,
  prior: Mapping.Tree) -> Session:
  match next previous:
    case Snapshot{start, end, document} Snapshot{old_start, old_end, old_document}:
      cached_session(next, undo, redo,
        Cache.render_change(D.Change{document, 0n, 0n, 0n}, start, end,
          old_start, old_end, cache, prior))

def select(session: Session, native_start: Nat, native_end: Nat) -> Session:
  match session:
    case Session{+snapshot, undo, redo, view, cache, +index}:
      select_cached(select_snapshot(snapshot, index, native_start, native_end), snapshot,
        undo, redo, cache, index)

def replace_snapshot(snapshot: Snapshot, +insert: String) -> Snapshot:
  match snapshot:
    case Snapshot{+start, +end, document}:
      +caret = Nat.add(Nat.min(start, end), String.length(insert))
      Snapshot{caret, caret, D.apply(document, start, end, insert)}

def changed_session(+change: D.Change, +caret: Nat, +snapshot: Snapshot,
  undo: List<&2, Snapshot>, cache: Cache.Cache, prior: Mapping.Tree) -> Session:
  match snapshot:
    case Snapshot{old_start, old_end, document}:
      cached_session(Snapshot{caret, caret, D.changed(change)}, snapshot <> undo, Nil{},
        Cache.render_change(change, caret, caret, old_start, old_end, cache, prior))

def edit_snapshot(selected: Snapshot, +insert: String, snapshot: Snapshot,
  undo: List<&2, Snapshot>, cache: Cache.Cache, prior: Mapping.Tree) -> Session:
  match selected:
    case Snapshot{+start, +end, document}:
      changed_session(D.apply_change(document, start, end, insert),
        Nat.add(Nat.min(start, end), String.length(insert)), snapshot, undo, cache, prior)

def edit(session: Session, native_start: Nat, native_end: Nat, insert: String) -> Session:
  match session:
    case Session{+snapshot, undo, redo, view, cache, +index}:
      edit_snapshot(select_snapshot(snapshot, index, native_start, native_end), insert,
        snapshot, undo, cache, index)

# Command ranges are already source positions. Do not map them through the view.
# The stored editor validates the range before it calls this function.
def edit_source(session: Session, start: Nat, end: Nat, insert: String) -> Session:
  match session:
    case Session{+snapshot, undo, redo, view, cache, index}:
      match snapshot:
        case Snapshot{old_start, old_end, document}:
          edit_snapshot(Snapshot{start, end, document}, insert,
            snapshot, undo, cache, index)

def replace_source(session: Session, +source: String) -> Session:
  match session:
    case Session{snapshot, undo, redo, view, cache, index}:
      +end = String.length(source)
      create(Snapshot{end, end, D.parse(source)}, snapshot <> undo, Nil{})

def undo(session: Session) -> Session:
  match session:
    case Session{snapshot, Nil{}, redo, view, cache, index}:
      Session{snapshot, Nil{}, redo, view, cache, index}
    case Session{snapshot, prior <> rest, redo, view, cache, index}:
      create(prior, rest, snapshot <> redo)

def redo(session: Session) -> Session:
  match session:
    case Session{snapshot, undo, Nil{}, view, cache, index}:
      Session{snapshot, undo, Nil{}, view, cache, index}
    case Session{snapshot, undo, next <> rest, view, cache, index}:
      create(next, snapshot <> undo, rest)
