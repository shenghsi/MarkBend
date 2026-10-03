import Base
import ../src/WorkspaceLoop.bend as Loop
import ../src/LiveParagraph.bend as Live
import ../src/AppSaveAs.bend as As
import ../src/AppSave.bend as Save
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Flat
import ./AppInputCheck.bend as Model
import ./AppSaveAsCheck.bend as Transaction
import ./StoredEditorCheck.bend as Stored
import ./DirectCheck.bend as Check

def events(values: List<Live.ParagraphEvent>, window: Window, workspace: As.Workspace) -> IO(Unit):
  match values:
    case Nil{}:
      do IO<Unit>:
        Check.check(Transaction.uncertain(workspace, Flat.request(Transaction.dirty())))
        Live.LiveParagraph.close(window)
        IO.print("Workspace events retained uncertain target, snapshot, baseline, and history")
    case event <> remaining:
      Loop.finish((window, event), workspace, w => v => events(remaining, w, v))

def unchanged(value: As.Workspace, state: Flat.State) -> Bool:
  match value:
    case As.Editing{document}:
      Model.same(document, Model.text(), state)
    case _:
      False{}

def pending(window: Window, +workspace: As.Workspace,
  rest: Window -> IO(Unit)) -> IO(Unit):
  Loop.candidate(window, workspace, As.Validated{Transaction.target()}, w => v =>
    do IO<Unit>:
      Check.check(unchanged(v, Flat.request(Transaction.dirty())))
      rest(w))

def main() -> IO(Unit):
  do IO<Unit>:
    initial : Editor.Session <- Stored.loaded(Editor.load(Flat.open([65])))
    +edited : Editor.Session <- Stored.accepted(Editor.replace_source(initial, Model.text()))
    workspace : As.Workspace = As.complete(As.start(As.Editing{Model.document(edited)},
      As.Validated{Transaction.target()}), 0n, Save.Uncertain{})
    window : Window <- Live.LiveParagraph.open(Model.text())
    Live.LiveParagraph.continue_stored(window, edited, w => +s =>
      Loop.candidate(w, As.Editing{Model.document(s)}, As.Cancelled{}, w => v =>
        do IO<Unit>:
          Check.check(unchanged(v, Transaction.dirty()))
          pending(w, As.Editing{Model.document(Editor.request(s))}, w =>
            events([Live.ParagraphSave{}, Live.ParagraphClosed{}, Live.ParagraphSelected{0, 0},
              Live.ParagraphChanged{"later😀"}, Live.ParagraphUndo{}, Live.ParagraphRedo{}, Live.ParagraphUndo{}], w, workspace))))
