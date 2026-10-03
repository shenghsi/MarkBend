import Base
import ./AppSaveAs.bend as As
import ./AppSave.bend as Save
import ./AppInput.bend as Input

# The app must keep Workspace through these decisions. A blocked operation
# returns the complete value, including its proposed target and snapshot.
type SaveDecision is Data:
  Ready{workspace: As.Workspace}
  SaveBlocked{workspace: As.Workspace}

type CloseDecision is Data:
  DocumentClose{workspace: As.Workspace, decision: Save.CloseDecision}
  CloseBlocked{workspace: As.Workspace}

type EndDecision is Data:
  CloseSafe{workspace: As.Workspace}
  Suspended{workspace: As.Workspace}

def save(value: As.Workspace) -> SaveDecision:
  match value:
    case As.Editing{document}:
      Ready{value}
    case value:
      SaveBlocked{value}

def close(+value: As.Workspace) -> CloseDecision:
  match value:
    case As.Editing{document}:
      DocumentClose{value, Save.close_requested(document)}
    case value:
      CloseBlocked{value}

def ended_document(result: Input.Ended, workspace: As.Workspace) -> EndDecision:
  match result:
    case Input.CloseSafe{document}:
      CloseSafe{workspace}
    case Input.Suspended{document}:
      Suspended{workspace}

def ended(+value: As.Workspace) -> EndDecision:
  match value:
    case As.Editing{document}:
      ended_document(Input.ended(document), value)
    case value:
      Suspended{value}
