import Base
import ../src/NewFileReconcile.bend as Observe
import ../src/AppSaveAs.bend as As
import ../src/AppSave.bend as Save
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./AppInputCheck.bend as Model
import ./AppSaveAsCheck.bend as Transaction
import ./StoredEditorCheck.bend as Stored
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def uncertain(value: As.Workspace) -> As.Workspace:
  match value:
    case As.Saving{document, target, id, snapshot}:
      As.Uncertain{document, target, id, snapshot}
    case value:
      value

def wrong_retained(value: As.Workspace, state: Flat.State) -> Bool:
  match value:
    case As.Uncertain{document, target, id, snapshot}:
      Transaction.wrong_retained(As.Saving{document, target, id, snapshot}, state)
    case _:
      False{}

def main() -> IO(Unit):
  +pending = Flat.request(Transaction.dirty())
  do IO<Unit>:
    initial : Editor.Session <- Stored.loaded(Editor.load(Flat.open([65])))
    edited : Editor.Session <- Stored.accepted(Editor.replace_source(initial, Model.text()))
    +saving : As.Workspace = As.start(As.Editing{Model.document(edited)}, As.Validated{Transaction.target()})
    +blocked : As.Workspace = uncertain(saving)
    Check.check(Transaction.uncertain(Observe.complete(blocked, 0n, Observe.RetainUncertain{}), pending))
    Check.check(Transaction.uncertain(Observe.complete(blocked, 1n, Observe.ConfirmedObservation{}), pending))
    Check.check(wrong_retained(uncertain(Transaction.wrong_snapshot(saving)), pending))
    Check.check(wrong_retained(Observe.complete(uncertain(Transaction.wrong_snapshot(saving)),
      0n, Observe.ConfirmedObservation{}), pending))
    Check.check(Transaction.adopted(Observe.complete(blocked, 0n, Observe.ConfirmedObservation{}),
      Model.text(), Flat.complete(pending, 0n, Flat.Confirmed{})))
    +later : As.Workspace = As.replace_source(blocked, "later😀")
    +finished : As.Workspace = Observe.complete(later, 0n, Observe.ConfirmedObservation{})
    Check.check(Transaction.adopted(finished, "later😀",
      Flat.complete(Flat.edit(pending, Encode.bytes(Utf8.encode("later😀"))), 0n, Flat.Confirmed{})))
    Check.check(Transaction.adopted(As.undo(finished), Model.text(), Flat.complete(pending, 0n, Flat.Confirmed{})))
    IO.print("New-file reconciliation retained stale observations and preserved later edits and history")
