import Base
import ../src/WorkspaceLoop.bend as Loop
import ../src/AppSaveAs.bend as As
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Flat
import ./StoredEditorCheck.bend as Stored
import ./DirectCheck.bend as Check
import ../src/NewFilePublish.bend as Publish

def not_started(value: Publish.Completion) -> Bool:
  match value:
    case Publish.NotStarted{As.Editing{App.Document{App.Untitled{}, session}}}:
      Stored.matches(session, "A", Flat.open([65]))
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    session : Editor.Session <- Stored.loaded(Editor.load(Flat.open([65])))
    result : Publish.Completion <- Publish.run_completion(As.Editing{App.with_session(App.Untitled{}, session)})
    Check.check(not_started(result))
    IO.print("Workspace loop module compile and not-started result check passed")
