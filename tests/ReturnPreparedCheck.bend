import Base
import ../src/ReturnCommand.bend as Return
import ../src/ListReturn.bend as Legacy
import ../src/StoredEditor.bend as Stored
import ../src/DirectState.bend as State
import ../src/BlockScene.bend as Scene
import ../src/BlockSceneCache.bend as Cache
import ../src/BlockIndex.bend as Tree
import ../src/SceneIndex.bend as Index
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as Storage
import ./HostPatchCheck.bend as Patch
import ./SessionViewCheck.bend as View
import ./DirectCheck.bend as Check
import ./IndexedReturnCheck.bend as Plan

def replayed(original: State.Session, final: State.Session) -> Bool:
  match original final:
    case State.Session{before, undo, redo, old_view, cache, old_index}
      State.Session{after, history, future, State.RawView{scene, host, edits}, next_cache, index}:
      Patch.matches(Patch.replay(edits, Patch.Replayed{
        Tree.from_list(~Scene.HostChunk, ~Patch.width, Cache.complete_host(old_index, Nil{})), True{}}),
        Cache.complete_host(index, Nil{}))

def selected_plan(snapshot: State.Snapshot) -> Legacy.Edit:
  match snapshot:
    case State.Snapshot{start, end, document}:
      Legacy.plan(State.document_source(document), start, end)

def verified(prepared: Return.Prepared, +original: Stored.Session,
  start: Nat, end: Nat) -> Bool:
  match prepared original:
    case Return.Prepared{edit, Stored.Accepted{Stored.Session{+editor, storage}}}
      Stored.Session{+before, original_storage}:
      Plan.same(edit, selected_plan(State.current(State.select(before, start, end)))) &&
        replayed(before, editor) && View.valid(editor)
    case _ _:
      False{}

def ends(fuel: Nat, +session: Stored.Session, +start: Nat, +end: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        Check.check(verified(Return.prepare(session, start, end), session, start, end))
        ends(rest, session, start, 1n+end)

def starts(fuel: Nat, +session: Stored.Session, +size: Nat, +start: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        ends(1n+size, session, start, 0n)
        starts(rest, session, size, 1n+start)

def ready(+session: Stored.Session) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      +size = Index.native_length(State.index(editor))
      starts(1n+size, session, size, 0n)

def fixture(source: String) -> IO(Unit):
  do IO<Unit>:
    session : Stored.Session <- Storage.loaded(Stored.load(Flat.open(Encode.bytes(Utf8.encode(source)))))
    ready(session)

def main() -> IO(Unit):
  do IO<Unit>:
    fixture("")
    fixture("- x")
    fixture("* **ab**")
    fixture("**ab**\n- x")
    fixture("- \t\r\n")
    fixture("# h\n\n- 中😀")
    fixture("```\n- x\n```\n")
    IO.print("Prepared Return plans and ordered patch replay match the original host scene for all selection pairs")
