import Base
import ../src/NewFileObserve.bend as Host
import ../src/AppSaveAs.bend as As
import ../src/AppSave.bend as Save
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./NewFilePublishDriverCheck.bend as Driver
import ./AppInputCheck.bend as Model
import ./StoredEditorCheck.bend as Stored
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def mode(value: String) -> String:
  match value:
    case "confirmed":
      "save"
    case _:
      "uncertain"

def target_retained(value: As.Workspace, +path: String, parent: String, expected: String) -> Bool:
  match value expected:
    case As.Uncertain{document, As.Target{requested, actual, key, directory}, id, snapshot} "retained":
      String.eq(requested, path) && String.eq(actual, path) &&
        Flat.bytes_equal(key, Encode.bytes(Utf8.encode("PATH1:" ++ path))) &&
        Flat.bytes_equal(directory, Encode.bytes(Utf8.encode(parent)))
    case As.Editing{document} "confirmed":
      True{}
    case _ _:
      False{}

def later_checked(+value: As.Workspace, +path: String, expected: String) -> Bool:
  match value expected:
    case As.Editing{App.Document{destination, session}} "confirmed":
      Stored.matches(session, "later😀", Flat.complete(Flat.edit(Flat.request(Flat.edit(Flat.open([65]),
        Encode.bytes(Utf8.encode(Model.text())))), Encode.bytes(Utf8.encode("later😀"))), 0n, Flat.Confirmed{})) &&
        Driver.checked(As.undo(value), path, "save")
    case As.Uncertain{App.Document{destination, session}, target, id, snapshot} "retained":
      Stored.matches(session, "later😀", Flat.edit(Flat.request(Flat.edit(Flat.open([65]),
        Encode.bytes(Utf8.encode(Model.text())))), Encode.bytes(Utf8.encode("later😀")))) &&
        Driver.checked(As.undo(value), path, "uncertain")
    case _ _:
      False{}

def run(+path: String, +parent: String, +expected: String) -> IO(Unit):
  do IO<Unit>:
    initial : Editor.Session <- Stored.loaded(Editor.load(Flat.open([65])))
    edited : Editor.Session <- Stored.accepted(Editor.replace_source(initial, Model.text()))
    +active : As.Workspace = As.start(As.Editing{App.with_session(App.Untitled{}, edited)},
      As.Validated{As.Target{path, path, Encode.bytes(Utf8.encode("PATH1:" ++ path)), Encode.bytes(Utf8.encode(parent))}})
    +result : As.Workspace <- Host.run(As.complete(active, 0n, Save.Uncertain{}))
    Check.check(Driver.checked(result, path, mode(expected)))
    Check.check(target_retained(result, path, parent, expected))
    +repeated : As.Workspace <- Host.run(result)
    Check.check(Driver.checked(repeated, path, mode(expected)))
    Check.check(target_retained(repeated, path, parent, expected))
    +later : As.Workspace <- Host.run(As.replace_source(As.complete(active, 0n, Save.Uncertain{}), "later😀"))
    Check.check(later_checked(later, path, expected))
    Check.check(target_retained(later, path, parent, expected))
    IO.print("New-file observation driver adoption and retained transaction passed")

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> path <> parent <> expected <> Nil{}:
      run(path, parent, expected)
    case _:
      IO.die(Unit, 1, "Supply target path, parent key, and expected result")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
