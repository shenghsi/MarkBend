import Base
import ../src/Document.bend as D
import ../src/BlockIndex.bend as Index
import ../src/BlockSceneCache.bend as Cache
import ../src/BlockScene.bend as Scene
import ../src/SceneIndex.bend as Mapping
import ../src/DirectState.bend as State
import ../src/StoredEditor.bend as Stored
import ../src/ReturnCommand.bend as Return
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./ReturnCommandCheck.bend as Result
import ./ReturnCommandBench.bend as Core
import ./StoredEditorCheck.bend as Storage
import ./RecoveryEditorCheck.bend as Encode
import ./DocumentCheck.bend as DocCheck
import ./SceneCacheCheck.bend as CacheCheck
import ./SessionViewCheck.bend as View
import ./HostPatchCheck.bend as Patch
import ./DirectCheck.bend as Check

def document(snapshot: State.Snapshot) -> D.Document:
  match snapshot:
    case State.Snapshot{start, end, document}:
      document

def prior(editor: State.Session) -> Cache.CachedScene:
  match editor:
    case State.Session{current, undo, redo, State.RawView{scene, host, patches}, cache, index}:
      Cache.CachedScene{scene, cache, index, host, patches}

def forced_document(change: D.Change, +blocks: Nat) -> Bool:
  match change:
    case D.Change{D.Document{+tree, next, parsed}, first, removed, added}:
      Nat.is_eq(Index.length(D.Block, tree), 65541n) &&
        Nat.is_eq(Index.count(D.Block, tree), blocks)

def forced_scene(+result: Cache.CachedScene) -> Bool:
  Nat.is_eq(Mapping.source_length(Cache.index(result)), 65541n) &&
    Nat.is_eq(Mapping.native_length(Cache.index(result)), 65541n)

def same_document(a: D.Document, b: D.Document) -> Bool:
  match a b:
    case D.Document{left, first, parsed} D.Document{right, later, other}:
      DocCheck.same_blocks(Index.flatten(D.Block, left, Nil{}),
        Index.flatten(D.Block, right, Nil{})) && Nat.is_eq(first, later)

def same_view(view: State.View, scene: Cache.CachedScene) -> Bool:
  match view:
    case State.View{reference, visible}:
      View.same_scene(Cache.scene(scene), reference)

def same_result(full: Stored.Session, changed: D.Change, scene: Cache.CachedScene) -> Bool:
  match full:
    case Stored.Session{+editor, storage}:
      same_document(D.changed(changed), document(State.current(editor))) &&
        same_view(State.view(editor), scene)

def verify_command(+baseline: Stored.Session, +changed: D.Change,
  +scene: Cache.CachedScene, +expected: String, saved: Flat.State) -> IO(Unit):
  do IO<Unit>:
    +full : Stored.Session <- Storage.accepted(Return.command(baseline, 65538n, 65538n))
    Check.check(Result.verified(full, expected, 65541n, 65541n, saved))
    Check.check(same_result(full, changed, scene))

def document_samples(fuel: Nat, +number: Nat, +baseline: Stored.Session,
  +doc: D.Document, +before: Cache.CachedScene, +expected: String,
  +blocks: Nat, +saved: Flat.State) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("Document Return kernel checks passed")
    case 1n+rest:
      do IO<Unit>:
        +start : Nat <- IO.now()
        +change : D.Change = D.apply_change(doc, 65538n, 65538n, "\n- ")
        Check.check(forced_document(change, blocks))
        +stop : Nat <- IO.now()
        Check.check(DocCheck.valid_change(doc, change))
        Check.check(DocCheck.matches(D.changed(change), expected))
        +scene : Cache.CachedScene = Cache.render_change(change, 65541n, 65541n,
          65538n, 65538n, Cache.cache(before), Cache.index(before))
        Check.check(CacheCheck.matches(scene, expected, 65541n, 65541n))
        Check.check(Patch.valid(before, scene))
        verify_command(baseline, change, scene, expected, saved)
        IO.print("return_kernel kind=document sample=" ++ Nat.show(number) ++
          " elapsed_ms=" ++ Nat.show(Nat.sub(stop, start)))
        document_samples(rest, 1n+number, baseline, doc, before, expected, blocks, saved)

def scene_samples(fuel: Nat, +number: Nat, +baseline: Stored.Session,
  +change: D.Change, +before: Cache.CachedScene, +expected: String, +saved: Flat.State) -> IO(Unit):
  match fuel:
    case 0n:
      IO.print("Scene Return kernel checks passed")
    case 1n+rest:
      do IO<Unit>:
        +start : Nat <- IO.now()
        +scene : Cache.CachedScene = Cache.render_change(change, 65541n, 65541n,
          65538n, 65538n, Cache.cache(before), Cache.index(before))
        Check.check(forced_scene(scene))
        +stop : Nat <- IO.now()
        Check.check(CacheCheck.matches(scene, expected, 65541n, 65541n))
        Check.check(Patch.valid(before, scene))
        verify_command(baseline, change, scene, expected, saved)
        IO.print("return_kernel kind=scene sample=" ++ Nat.show(number) ++
          " elapsed_ms=" ++ Nat.show(Nat.sub(stop, start)))
        scene_samples(rest, 1n+number, baseline, change, before, expected, saved)

def prepared(+baseline: Stored.Session, +source: String, +expected: String,
  +saved: Flat.State) -> IO(Unit):
  match baseline:
    case Stored.Session{+editor, storage}:
      +doc = document(State.current(editor))
      +before = prior(editor)
      +blocks = CacheCheck.count(D.parse(expected))
      do IO<Unit>:
        Check.check(Core.preflight(baseline, 65538n, 65538n))
        Check.check(DocCheck.matches(doc, source))
        Check.check(CacheCheck.matches(before, source, 65538n, 65538n))
        Check.check(Nat.is_eq(blocks, 2n))
        document_samples(20n, 1n, baseline, doc, before, expected, blocks, saved)
        +change : D.Change = D.apply_change(doc, 65538n, 65538n, "\n- ")
        Check.check(DocCheck.valid_change(doc, change))
        Check.check(DocCheck.matches(D.changed(change), expected))
        Check.check(forced_document(change, blocks))
        scene_samples(20n, 1n, baseline, change, before, expected, saved)

def main() -> IO(Unit):
  +source = "- " ++ Result.repeated(65536n, "")
  +expected = Core.appended(source, "\n- ")
  +initial = Flat.open(Encode.bytes(Utf8.encode(source)))
  +saved = Flat.edit(initial, Encode.bytes(Utf8.encode(expected)))
  do IO<Unit>:
    session : Stored.Session <- Storage.loaded(Stored.load(initial))
    prepared(Stored.select(session, 65538n, 65538n), source, expected, saved)
