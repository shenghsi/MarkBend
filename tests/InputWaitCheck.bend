import Base
import ../src/InputWait.bend as Host
import ../src/AppInput.bend as Input
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ./AppInputCheck.bend as Model
import ./StoredEditorCheck.bend as Stored
import ./DirectCheck.bend as Check
import ./RecoveryEditorCheck.bend as Encode
import ../src/Utf8.bend as Utf8

def outcomes(mode: String) -> List<&2, Bool>:
  match mode:
    case "repeat":
      [True{}, True{}]
    case "old":
      [True{}, False{}]
    case "extra":
      [True{}, False{}]
    case "resume":
      [True{}]
    case "partial":
      [True{}]
    case _:
      [False{}]

def checked(wake: Input.Wake, expected: Bool, +document: App.Document,
  +state: Save.State) -> IO(Unit):
  match wake expected:
    case Input.Resumed{} True{}:
      Check.check(Model.history(Input.resume(document, Input.Resumed{}), state))
    case Input.Unavailable{} False{}:
      Check.check(Model.retained(Input.resume(document, Input.Unavailable{}), Model.text(), state))
    case _ _:
      IO.die(Unit, 1, "Private input wake outcome failed")

def run(values: List<&2, Bool>, +document: App.Document, +state: Save.State) -> IO(Unit):
  match values:
    case Nil{}:
      IO.print("Private wake retained the complete document across host waits")
    case expected <> rest:
      do IO<Unit>:
        wake : Input.Wake <- Host.wait(3, 4)
        checked(wake, expected, document, state)
        run(rest, document, state)

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> mode <> Nil{}:
      +state = Save.request(Save.edit(Save.open([65]), Encode.bytes(Utf8.encode(Model.text()))))
      do IO<Unit>:
        initial : Editor.Session <- Stored.loaded(Editor.load(Save.open([65])))
        edited : Editor.Session <- Stored.accepted(Editor.replace_source(initial, Model.text()))
        run(outcomes(mode), Model.document(Editor.request(edited)), state)
    case _:
      IO.die(Unit, 1, "Supply private wake mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
