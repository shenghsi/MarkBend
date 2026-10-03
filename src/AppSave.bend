import Base
import ./AppDocument.bend as App
import ./StoredEditor.bend as Editor
import ./StorageHistory.bend as History
import ./PersistentSave.bend as Persistent
import ./ByteBuffer.bend as Bytes
import ./SaveState.bend as Save

type Request is Data:
  Request{path: String, identity: List<&2, U32>, id: Nat,
    baseline: Bytes.Buffer, bytes: Bytes.Buffer}

type Preparation is Data:
  Ready{document: App.Document, request: Request}
  Pending{document: App.Document}
  Unavailable{document: App.Document}

type Outcome is Data:
  Confirmed{}
  OldKept{}
  Uncertain{}
  Conflict{}
  UnavailableHost{}

type CloseChoice is Data:
  SaveChoice{}
  DiscardChoice{}
  CancelChoice{}

type CloseDecision is Data:
  CloseNow{document: App.Document}
  KeepOpen{document: App.Document}
  SaveFirst{document: App.Document}

# A retained ticket must not cause another host operation. Request is created
# only on the transition from no ticket to one ticket.
# Internal helper: the host loop must enter through prepare, never requested.
def requested(document: App.Document) -> Preparation:
  match document:
    case App.Document{App.Resolved{requested, +path, +identity},
      Editor.Session{editor, History.Session{current, undo, redo,
        Persistent.State{bytes, +baseline, next, Some{Persistent.Ticket{+id, +snapshot}}}, state}}}:
      Ready{document, Request{path, identity, id, baseline, snapshot}}
    case document:
      Unavailable{document}

def prepare_resolved(+document: App.Document) -> Preparation:
  match document:
    case App.Document{destination, Editor.Session{editor,
      History.Session{current, undo, redo, Persistent.State{bytes, baseline, next, None{}}, state}}}:
      requested(App.with_session(destination, Editor.request(
        Editor.Session{editor, History.Session{current, undo, redo,
          Persistent.State{bytes, baseline, next, None{}}, state}})))
    case document:
      Pending{document}

def prepare(document: App.Document) -> Preparation:
  match document:
    case App.Document{App.Resolved{requested, path, identity}, session}:
      prepare_resolved(App.with_session(App.Resolved{requested, path, identity}, session))
    case document:
      Unavailable{document}

def completion(outcome: Outcome) -> Save.Outcome:
  match outcome:
    case Confirmed{}:
      Save.Confirmed{}
    case Uncertain{}:
      Save.ReplacementUncertain{}
    case _:
      Save.OldKept{}

# Conflict and unavailable mean that the host did not replace the file.
# Any host failure after replacement must use Uncertain instead.
def complete(document: App.Document, id: Nat, outcome: Outcome) -> App.Document:
  match document:
    case App.Document{destination, session}:
      App.with_session(destination, Editor.complete(session, id, completion(outcome)))

def pending(session: Editor.Session) -> Bool:
  match session:
    case Editor.Session{editor, History.Session{current, undo, redo,
      Persistent.State{bytes, baseline, next, Some{ticket}}, state}}:
      True{}
    case _:
      False{}

# Equality with the baseline alone is insufficient while replacement is unknown.
def can_close(+session: Editor.Session) -> Bool:
  Bool.not(pending(session)) && Bool.not(Editor.dirty(session))

def close_decided(clean: Bool, document: App.Document) -> CloseDecision:
  match clean:
    case True{}:
      CloseNow{document}
    case False{}:
      KeepOpen{document}

def close_requested(+document: App.Document) -> CloseDecision:
  match document:
    case App.Document{destination, session}:
      close_decided(can_close(session), document)

def choose_close(document: App.Document, choice: CloseChoice) -> CloseDecision:
  match choice:
    case CancelChoice{}:
      KeepOpen{document}
    case DiscardChoice{}:
      CloseNow{document}
    case SaveChoice{}:
      SaveFirst{document}

# Save-on-close requires confirmation, even if an intervening undo restored
# the old baseline. This model is for a synchronous host operation. The host
# must finish the operation before it accepts another choice, including Discard.
def close_completed(document: App.Document, outcome: Outcome) -> CloseDecision:
  match outcome:
    case Confirmed{}:
      close_requested(document)
    case _:
      KeepOpen{document}
