import Base
import ../src/LiveParagraph.bend as Live
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ./StoredEditorCheck.bend as Stored
import ./AppInputCheck.bend as Model
import ./DirectCheck.bend as Check
import ./RecoveryEditorCheck.bend as Encode
import ../src/Utf8.bend as Utf8

def main() -> IO(Unit):
  +state = Save.edit(Save.request(Save.edit(Save.open([65]), Encode.bytes(Utf8.encode(Model.text())))), [65])
  do IO<Unit>:
    initial : Editor.Session <- Stored.loaded(Editor.load(Save.open([65])))
    edited : Editor.Session <- Stored.accepted(Editor.replace_source(initial, Model.text()))
    +pending : Editor.Session = Editor.undo(Editor.request(edited))
    Check.check(Model.same(Model.document(pending), "A", state))
    IO.print("Pending state checked before input-ended dispatch")
    window : Window <- Live.LiveParagraph.open("A")
    Live.LiveParagraph.finish_document((window, Live.ParagraphInputEnded{}), Model.document(pending),
      w => d => IO.die(Unit, 1, "Suspension returned without a resume service"))
