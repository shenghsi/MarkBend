import Base
import ../src/LiveParagraph.bend as Live
import ../src/WorkspaceLoop.bend as Loop
import ../src/AppSaveAs.bend as As
import ../src/AppSave.bend as Save
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./AppInputCheck.bend as Model
import ./StoredEditorCheck.bend as Stored
import ./NewFilePublishDriverCheck.bend as CheckState
import ./NewFileObserveDriverCheck.bend as ObserveState
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def Driver.prepare() -> IO(Unit):
  import "./native_workspace_recheck.c"

def Driver.finish(window: Window, expected: String) -> IO(Window):
  import "./native_workspace_recheck.c"

def mode(expected: String) -> String:
  match expected:
    case "confirmed":
      "save"
    case _:
      "uncertain"

def run(+path: String, +parent: String, +expected: String) -> IO(Unit):
  do IO<Unit>:
    initial : Editor.Session <- Stored.loaded(Editor.load(Flat.open([65])))
    +edited : Editor.Session <- Stored.accepted(Editor.replace_source(initial, Model.text()))
    active : As.Workspace = As.start(As.Editing{App.with_session(App.Untitled{}, edited)},
      As.Validated{As.Target{path, path, Encode.bytes(Utf8.encode("PATH1:" ++ path)), Encode.bytes(Utf8.encode(parent))}})
    workspace : As.Workspace = As.complete(active, 0n, Save.Uncertain{})
    Driver.prepare()
    window : Window <- Live.LiveParagraph.open(Model.text())
    Live.LiveParagraph.continue_stored(window, edited, w => s =>
      Loop.run(3n, w, workspace, w => +result =>
        do IO<Unit>:
          Check.check(CheckState.checked(result, path, mode(expected)))
          Check.check(ObserveState.target_retained(result, path, parent, expected))
          verified : Window <- Driver.finish(w, expected)
          Live.LiveParagraph.close(verified)
          IO.print("Native workspace Recheck event and exact transaction check passed")))

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> path <> parent <> expected <> Nil{}:
      run(path, parent, expected)
    case _:
      IO.die(Unit, 1, "Supply target path, parent identity, and expected result")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
