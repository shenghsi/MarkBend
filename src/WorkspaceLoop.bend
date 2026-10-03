import Base
import ./LiveParagraph.bend as Live
import ./AppSaveAs.bend as As
import ./AppDocument.bend as App
import ./WorkspaceControl.bend as Control
import ./NewFilePublish.bend as Publish

# Compatibility interface. Main startup uses the same workspace loop in LiveParagraph.

def blocked(window: Window, value: As.Workspace, rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  Live.LiveParagraph.workspace_blocked(window, value, rest)

def ended(window: Window, decision: Control.EndDecision, rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  Live.LiveParagraph.workspace_ended(window, decision, rest)

def stored(update: Window & Live.ParagraphEvent, value: As.Workspace, current: App.Document, rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  Live.LiveParagraph.workspace_stored(update, value, current, rest)

def finish(update: Window & Live.ParagraphEvent, value: As.Workspace, rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  Live.LiveParagraph.workspace_finish(update, value, rest)

def completed(window: Window, result: Publish.Completion, rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  Live.LiveParagraph.workspace_completed(window, result, rest)

def candidate(window: Window, value: As.Workspace, choice: As.Candidate, rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  Live.LiveParagraph.workspace_candidate(window, value, choice, rest)

def save_as(window: Window, value: As.Workspace, requested: String, rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  Live.LiveParagraph.workspace_save_as(window, value, requested, rest)

def run(fuel: Nat, window: Window, value: As.Workspace, rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  Live.LiveParagraph.workspace_run(fuel, window, value, rest)
