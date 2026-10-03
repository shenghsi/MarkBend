import Base
import ../src/WorkspaceControl.bend as Control
import ../src/AppSaveAs.bend as As
import ../src/AppSave.bend as Save
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Flat
import ./AppInputCheck.bend as Model
import ./AppSaveAsCheck.bend as Transaction
import ./StoredEditorCheck.bend as Stored
import ./DirectCheck.bend as Check

def blocked_save(value: Control.SaveDecision, state: Flat.State) -> Bool:
  match value:
    case Control.SaveBlocked{workspace}:
      Transaction.uncertain(workspace, state)
    case _:
      False{}

def blocked_close(value: Control.CloseDecision, state: Flat.State) -> Bool:
  match value:
    case Control.CloseBlocked{workspace}:
      Transaction.uncertain(workspace, state)
    case _:
      False{}

def suspended(value: Control.EndDecision, state: Flat.State) -> Bool:
  match value:
    case Control.Suspended{workspace}:
      Transaction.uncertain(workspace, state)
    case _:
      False{}

def clean(value: Control.EndDecision) -> Bool:
  match value:
    case Control.CloseSafe{As.Editing{document}}:
      Model.same(document, "A", Flat.open([65]))
    case _:
      False{}

def main() -> IO(Unit):
  +pending = Flat.request(Transaction.dirty())
  do IO<Unit>:
    +initial : Editor.Session <- Stored.loaded(Editor.load(Flat.open([65])))
    edited : Editor.Session <- Stored.accepted(Editor.replace_source(initial, Model.text()))
    +blocked : As.Workspace = As.complete(As.start(As.Editing{Model.document(edited)},
      As.Validated{Transaction.target()}), 0n, Save.Uncertain{})
    Check.check(blocked_save(Control.save(blocked), pending))
    Check.check(blocked_close(Control.close(blocked), pending))
    Check.check(suspended(Control.ended(blocked), pending))
    Check.check(clean(Control.ended(As.Editing{Model.document(initial)})))
    IO.print("Workspace save, close, and input-ended guards retained uncertainty")
