import Base
import ./Experiment.bend as E
import ./DirectState.bend as State
import ./BlockScene.bend as Scene
import ./ListReturn.bend as ListReturn
import ./SceneIndex.bend as Mapping
import ./BlockSceneCache.bend as Cache
import ./StoredEditor.bend as Stored
import ./SaveState.bend as Save
import ./Utf8.bend as Utf8
import ./ResolvedOpen.bend as Open
import ./InitialFile.bend as Reader
import ./InitialOpen.bend as Initial
import ./RecoveryConfig.bend as RecoveryConfig
import ./RecoverySettings.bend as RecoverySettings
import ./RecoveryScan.bend as RecoveryScan
import ./AppRecovery.bend as Recovery
import ./AppDocument.bend as App
import ./AppSave.bend as Saving
import ./DocumentSave.bend as Disk
import ./OpenConfig.bend as Config
import ./AppInput.bend as Input
import ./InputSuspend.bend as Suspension
import ./AppSaveAs.bend as As
import ./WorkspaceControl.bend as Control
import ./NewFileTarget.bend as Target
import ./NewFilePublish.bend as Publish
import ./NewFileObserve.bend as Observe
import ./ReturnCommand.bend as Return

type ParagraphEvent is Data:
  ParagraphChanged{text: String}
  ParagraphSelected{start: U32, end: U32}
  ParagraphEdit{start: U32, end: U32, text: String}
  ParagraphReturn{start: U32, end: U32}
  ParagraphUndo{}
  ParagraphRedo{}
  ParagraphSave{}
  ParagraphSaveAs{requested: String}
  ParagraphChooseSaveAs{}
  ParagraphRecheckSaveAs{}
  ParagraphClosed{}
  ParagraphInputEnded{}
  ParagraphDraftEnded{}

# Close choice codes: 0 Cancel, 1 Save, 2 Discard. Unknown choices cancel.
def LiveParagraph.close_choice(window: Window) -> IO(Window & U32):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

def LiveParagraph.status(window: Window, message: String) -> IO(Window):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

type SaveAsPick is Data:
  SaveAsSelected{requested: String}
  SaveAsCancelled{}
  SaveAsPickerUnavailable{}

def LiveParagraph.pick_save_as(window: Window) -> IO(Window & SaveAsPick):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

# Uses `Window` as the affine native handle because Bend 2 cannot define a new
# opaque handle type. Only this module may use the handle.
def LiveParagraph.open(initial: String) -> IO(Window):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

def LiveParagraph.next(window: Window) -> IO(Window & ParagraphEvent):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

def LiveParagraph.set(
  window: Window, source: String
) -> IO(Window):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

# Source positions count Unicode scalars. Only inserted text crosses the host.
def LiveParagraph.replace(window: Window, start: Nat, end: Nat, text: String) -> IO(Window):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

# Send an ordered scene in one effect. The host interprets only text and styles.
def LiveParagraph.append_chunks(window: Window, chunks: List<&2, Scene.HostChunk>, cacheable: Bool) -> IO(Window):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

def LiveParagraph.patch_chunks(window: Window, patches: List<&2, Scene.HostPatch>) -> IO(Window):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

def LiveParagraph.append_scene(window: Window, runs: List<&2, Scene.Run>) -> IO(Window):
  LiveParagraph.append_chunks(window, [Scene.HostChunk{0n, True{}, runs}], False{})

# Style codes: 0 is plain, 1 is strong, 2 is emphasis, 3 is code.
def LiveParagraph.append(window: Window, text: String, style: U32) -> IO(Window):
  LiveParagraph.append_scene(window, [Scene.Run{text, style}])

def LiveParagraph.close(window: Window) -> IO(Unit):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

# Finish a complete scene and set its UTF-16 selection. The host receives no
# Markdown rules. It displays the exact runs and native selection from Bend.
def LiveParagraph.project(window: Window, start: U32, end: U32) -> IO(Window):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

def LiveParagraph.draw_runs(runs: List<&2, E.RenderRun>, window: Window) -> IO(Window):
  match runs:
    case Nil{}:
      IO.pure(Window, window)
    case E.PlainRun{text} <> rest:
      do IO<Window>:
        next : Window <- LiveParagraph.append(window, text, 0)
        LiveParagraph.draw_runs(rest, next)
    case E.StrongRun{text} <> rest:
      do IO<Window>:
        next : Window <- LiveParagraph.append(window, text, 1)
        LiveParagraph.draw_runs(rest, next)
    case E.EmphasisRun{text} <> rest:
      do IO<Window>:
        next : Window <- LiveParagraph.append(window, text, 2)
        LiveParagraph.draw_runs(rest, next)
    case E.CodeRun{text} <> rest:
      do IO<Window>:
        next : Window <- LiveParagraph.append(window, text, 3)
        LiveParagraph.draw_runs(rest, next)

def LiveParagraph.draw_scene_runs(runs: List<&2, Scene.Run>, window: Window) -> IO(Window):
  LiveParagraph.append_scene(window, runs)

def LiveParagraph.draw_scene(scene: Scene.Scene, window: Window) -> IO(Window):
  match scene:
    case Scene.Scene{runs, points}:
      LiveParagraph.draw_scene_runs(runs, window)

def LiveParagraph.native_selection(collapsed: Bool, +index: Mapping.Tree,
  +start: Nat, end: Nat) -> Nat & Nat:
  match collapsed:
    case True{}:
      +point = Mapping.to_native(index, start)
      (point, point)
    case False{}:
      (Mapping.to_native(index, start), Mapping.to_native(index, end))

def LiveParagraph.present_chunks(window: Window, host: List<&2, Scene.HostChunk>,
  selection: Nat & Nat) -> IO(Window):
  match selection:
    case (native_start, native_end):
      do IO<Window>:
        drawn : Window <- LiveParagraph.append_chunks(window, host, True{})
        LiveParagraph.project(drawn, U32.from_nat(native_start), U32.from_nat(native_end))

def LiveParagraph.present_selection(window: Window, source: String, host: List<&2, Scene.HostChunk>,
  selection: Nat & Nat) -> IO(Window):
  do IO<Window>:
    cleared : Window <- LiveParagraph.set(window, source)
    LiveParagraph.present_chunks(cleared, host, selection)

def LiveParagraph.project_selection(window: Window, selection: Nat & Nat) -> IO(Window):
  match selection:
    case (start, end):
      LiveParagraph.project(window, U32.from_nat(start), U32.from_nat(end))

def LiveParagraph.present_view(window: Window, session: State.Session) -> IO(Window):
  match session:
    case State.Session{State.Snapshot{+start, +end, document}, undo, redo,
      State.RawView{scene, host, patches}, cache, index}:
      do IO<Window>:
        drawn : Window <- LiveParagraph.patch_chunks(window, patches)
        LiveParagraph.project_selection(drawn,
          LiveParagraph.native_selection(Nat.is_eq(start, end), index, start, end))

def LiveParagraph.complete_chunks(host: List<&2, Scene.HostChunk>, index: Mapping.Tree) -> List<&2, Scene.HostChunk>:
  match host:
    case Nil{}:
      Cache.complete_host(index, Nil{})
    case head <> rest:
      head <> rest

def LiveParagraph.present(window: Window, session: State.Session) -> IO(Window):
  match session:
    case State.Session{State.Snapshot{+start, +end, document}, undo, redo,
      State.RawView{scene, host, patches}, cache, +index}:
      LiveParagraph.present_selection(window, State.document_source(document),
        LiveParagraph.complete_chunks(host, index),
        LiveParagraph.native_selection(Nat.is_eq(start, end),
          index, start, end))

def LiveParagraph.continue_session(
  window: Window, +session: State.Session,
  rest: Window -> State.Session -> IO(Unit)
) -> IO(Unit):
  do IO<Unit>:
    shown : Window <- LiveParagraph.present(window, session)
    rest(shown, session)

def LiveParagraph.continue_edit_range(window: Window, selection: Nat & Nat,
  +session: State.Session, +text: String, rest: Window -> State.Session -> IO(Unit)) -> IO(Unit):
  match selection:
    case (start, end):
      do IO<Unit>:
        changed : Window <- LiveParagraph.replace(window, start, end, text)
        shown : Window <- LiveParagraph.present_view(changed, session)
        rest(shown, session)

def LiveParagraph.continue_edit(window: Window, +session: State.Session,
  +start: Nat, +end: Nat, +text: String, rest: Window -> State.Session -> IO(Unit)) -> IO(Unit):
  selection = State.source_selection(Nat.is_eq(start, end), State.index(session), start, end)
  next = State.edit(session, start, end, text)
  LiveParagraph.continue_edit_range(window, selection, next, text, rest)

def LiveParagraph.direct_return(window: Window, prepared: Return.DirectPrepared,
  rest: Window -> State.Session -> IO(Unit)) -> IO(Unit):
  match prepared:
    case Return.DirectPrepared{edit, session}:
      match edit:
        case ListReturn.Edit{start, end, text}:
          LiveParagraph.continue_edit_range(window, (start, end), session, text, rest)

def LiveParagraph.finish(
  update: Window & ParagraphEvent,
  session: State.Session,
  rest: Window -> State.Session -> IO(Unit)
) -> IO(Unit):
  (window, event) = update
  match event:
    case ParagraphClosed{}:
      LiveParagraph.close(window)
    case ParagraphInputEnded{}:
      LiveParagraph.close(window)
    case ParagraphDraftEnded{}:
      do IO<Unit>:
        Suspension.wait()
        rest(window, session)
    case ParagraphChanged{next_text}:
      LiveParagraph.continue_session(window, State.replace_source(session, next_text), rest)
    case ParagraphSelected{start, end}:
      LiveParagraph.continue_edit_range(window, (0n, 0n),
        State.select(session, U32.to_nat(start), U32.to_nat(end)), "", rest)
    case ParagraphEdit{start, end, text}:
      LiveParagraph.continue_edit(window, session, U32.to_nat(start), U32.to_nat(end), text, rest)
    case ParagraphReturn{start, end}:
      LiveParagraph.direct_return(window,
        Return.prepare_direct(session, U32.to_nat(start), U32.to_nat(end)), rest)
    case ParagraphUndo{}:
      LiveParagraph.continue_session(window, State.undo(session), rest)
    case ParagraphRedo{}:
      LiveParagraph.continue_session(window, State.redo(session), rest)
    case ParagraphSave{}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save needs a resolved file")
        rest(shown, session)
    case ParagraphSaveAs{requested}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save As needs an app workspace")
        rest(shown, session)
    case ParagraphChooseSaveAs{}:
      rest(window, session)
    case ParagraphRecheckSaveAs{}:
      rest(window, session)

# The finite fuel keeps the proof boundary sound. A later host wake starts a new
# session if this large safety bound is ever reached.
def LiveParagraph.run(fuel: Nat, window: Window, session: State.Session) -> IO(Unit):
  match fuel:
    case 0n:
      LiveParagraph.close(window)
    case 1n+rest:
      do IO<Unit>:
        update : (Window & ParagraphEvent) <- LiveParagraph.next(window)
        LiveParagraph.finish(
          update,
          session,
          next_window => next_history =>
            LiveParagraph.run(rest, next_window, next_history)
        )

def LiveParagraph.continue_stored(window: Window, +session: Stored.Session,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match session:
    case Stored.Session{editor, storage}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.present(window, editor)
        rest(shown, session)

def LiveParagraph.stored_replacement(window: Window, value: Stored.EditResult,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match value:
    case Stored.Accepted{session}:
      LiveParagraph.continue_stored(window, session, rest)
    case Stored.Rejected{session}:
      LiveParagraph.continue_stored(window, session, rest)

def LiveParagraph.stored_edit(window: Window, selection: Nat & Nat,
  value: Stored.EditResult, text: String,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match value:
    case Stored.Accepted{+session}:
      match session:
        case Stored.Session{editor, storage}:
          LiveParagraph.continue_edit_range(window, selection, editor, text,
            w => e => rest(w, session))
    case Stored.Rejected{session}:
      LiveParagraph.continue_stored(window, session, rest)

def LiveParagraph.stored_selection(window: Window, +selected: Stored.Session,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match selected:
    case Stored.Session{editor, storage}:
      LiveParagraph.continue_edit_range(window, (0n, 0n), editor, "",
        w => e => rest(w, selected))

def LiveParagraph.stored_return(window: Window, prepared: Return.Prepared,
  rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  match prepared:
    case Return.Prepared{edit, result}:
      match edit:
        case ListReturn.Edit{start, end, text}:
          LiveParagraph.stored_edit(window, (start, end), result, text, rest)

def LiveParagraph.finish_stored(update: Window & ParagraphEvent,
  +session: Stored.Session, rest: Window -> Stored.Session -> IO(Unit)) -> IO(Unit):
  (window, event) = update
  match event session:
    case ParagraphClosed{} _:
      LiveParagraph.close(window)
    case ParagraphInputEnded{} _:
      LiveParagraph.close(window)
    case ParagraphDraftEnded{} session:
      do IO<Unit>:
        Suspension.wait()
        rest(window, session)
    case ParagraphChanged{text} session:
      LiveParagraph.stored_replacement(window, Stored.replace_source(session, text), rest)
    case ParagraphSelected{start, end} session:
      LiveParagraph.stored_selection(window,
        Stored.select(session, U32.to_nat(start), U32.to_nat(end)), rest)
    case ParagraphReturn{start, end} session:
      LiveParagraph.stored_return(window,
        Return.prepare(session, U32.to_nat(start), U32.to_nat(end)), rest)
    case ParagraphEdit{start, end, +text} Stored.Session{editor, storage}:
      +first = U32.to_nat(start)
      +last = U32.to_nat(end)
      LiveParagraph.stored_edit(window,
        State.source_selection(Nat.is_eq(first, last), State.index(editor), first, last),
        Stored.edit(session, first, last, text), text, rest)
    case ParagraphUndo{} session:
      LiveParagraph.continue_stored(window, Stored.undo(session), rest)
    case ParagraphRedo{} session:
      LiveParagraph.continue_stored(window, Stored.redo(session), rest)
    case ParagraphSave{} session:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save needs a resolved file")
        rest(shown, session)
    case ParagraphSaveAs{requested} session:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save As needs an app workspace")
        rest(shown, session)
    case ParagraphChooseSaveAs{} session:
      rest(window, session)
    case ParagraphRecheckSaveAs{} session:
      rest(window, session)

def LiveParagraph.save_message(outcome: Saving.Outcome) -> String:
  match outcome:
    case Saving.Confirmed{}:
      "Saved"
    case Saving.OldKept{}:
      "Save failed. The file was not replaced"
    case Saving.Conflict{}:
      "The file changed on disk. Save stopped"
    case Saving.Uncertain{}:
      "Save could not be confirmed. Keep this document open"
    case Saving.UnavailableHost{}:
      "Save is unavailable on this host"

def LiveParagraph.after_save_close(window: Window, value: Saving.CloseDecision,
  rest: Window -> App.Document -> IO(Unit)) -> IO(Unit):
  match value:
    case Saving.CloseNow{document}:
      LiveParagraph.close(window)
    case Saving.KeepOpen{document}:
      rest(window, document)
    case Saving.SaveFirst{document}:
      rest(window, document)

def LiveParagraph.close_saved(close: Bool, window: Window, document: App.Document,
  outcome: Saving.Outcome, rest: Window -> App.Document -> IO(Unit)) -> IO(Unit):
  match close:
    case False{}:
      rest(window, document)
    case True{}:
      LiveParagraph.after_save_close(window, Saving.close_completed(document, outcome), rest)

def LiveParagraph.save_prepared(window: Window, value: Saving.Preparation, close: Bool,
  rest: Window -> App.Document -> IO(Unit)) -> IO(Unit):
  match value:
    case Saving.Ready{document, +request}:
      match request:
        case Saving.Request{path, identity, id, baseline, bytes}:
          do IO<Unit>:
            +outcome : Saving.Outcome <- Disk.write(request)
            shown : Window <- LiveParagraph.status(window, LiveParagraph.save_message(outcome))
            LiveParagraph.close_saved(close, shown, Saving.complete(document, id, outcome), outcome, rest)
    case Saving.Pending{document}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save is pending. Keep this document open")
        rest(shown, document)
    case Saving.Unavailable{document}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save As is unavailable for this document")
        rest(shown, document)

def LiveParagraph.close_decision(window: Window, value: Saving.CloseDecision,
  rest: Window -> App.Document -> IO(Unit)) -> IO(Unit):
  match value:
    case Saving.CloseNow{document}:
      LiveParagraph.close(window)
    case Saving.KeepOpen{document}:
      rest(window, document)
    case Saving.SaveFirst{document}:
      LiveParagraph.save_prepared(window, Saving.prepare(document), True{}, rest)

def LiveParagraph.input_ended(window: Window, value: Input.Ended,
  rest: Window -> App.Document -> IO(Unit)) -> IO(Unit):
  match value:
    case Input.CloseSafe{document}:
      LiveParagraph.close(window)
    case Input.Suspended{document}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Input ended. Unsaved document retained; resume is unavailable")
        Suspension.wait()
        rest(shown, document)

def LiveParagraph.chosen_close(value: Window & U32, document: App.Document,
  rest: Window -> App.Document -> IO(Unit)) -> IO(Unit):
  match value:
    case (window, 3):
      LiveParagraph.input_ended(window, Input.ended(document), rest)
    case (window, 1):
      LiveParagraph.close_decision(window, Saving.choose_close(document, Saving.SaveChoice{}), rest)
    case (window, 2):
      LiveParagraph.close_decision(window, Saving.choose_close(document, Saving.DiscardChoice{}), rest)
    case (window, _):
      LiveParagraph.close_decision(window, Saving.choose_close(document, Saving.CancelChoice{}), rest)

def LiveParagraph.request_close(window: Window, decision: Saving.CloseDecision,
  rest: Window -> App.Document -> IO(Unit)) -> IO(Unit):
  match decision:
    case Saving.CloseNow{document}:
      LiveParagraph.close(window)
    case Saving.KeepOpen{document}:
      do IO<Unit>:
        choice : Window & U32 <- LiveParagraph.close_choice(window)
        LiveParagraph.chosen_close(choice, document, rest)
    case Saving.SaveFirst{document}:
      LiveParagraph.save_prepared(window, Saving.prepare(document), True{}, rest)

def LiveParagraph.run_stored(fuel: Nat, window: Window, session: Stored.Session) -> IO(Unit):
  match fuel:
    case 0n:
      LiveParagraph.close(window)
    case 1n+remaining:
      do IO<Unit>:
        update : Window & ParagraphEvent <- LiveParagraph.next(window)
        LiveParagraph.finish_stored(update, session,
          w => s => LiveParagraph.run_stored(remaining, w, s))

def LiveParagraph.finish_document(update: Window & ParagraphEvent, document: App.Document,
  rest: Window -> App.Document -> IO(Unit)) -> IO(Unit):
  match update document:
    case (window, ParagraphDraftEnded{}) document:
      LiveParagraph.input_ended(window, Input.Suspended{document}, rest)
    case (window, ParagraphInputEnded{}) document:
      LiveParagraph.input_ended(window, Input.ended(document), rest)
    case (window, ParagraphSave{}) document:
      LiveParagraph.save_prepared(window, Saving.prepare(document), False{}, rest)
    case (window, ParagraphSaveAs{requested}) document:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save As needs an app workspace")
        rest(shown, document)
    case (window, ParagraphChooseSaveAs{}) document:
      rest(window, document)
    case (window, ParagraphRecheckSaveAs{}) document:
      rest(window, document)
    case (window, ParagraphClosed{}) document:
      LiveParagraph.request_close(window, Saving.close_requested(document), rest)
    case update App.Document{destination, session}:
      LiveParagraph.finish_stored(update, session,
        w => s => rest(w, App.with_session(destination, s)))

# Finite pump: exhaustion returns the complete state to its IO driver. Fuel
# never supplies permission to close or discard a document.
def LiveParagraph.run_document(fuel: Nat, window: Window, document: App.Document,
  rest: Window -> App.Document -> IO(Unit)) -> IO(Unit):
  match fuel:
    case 0n:
      rest(window, document)
    case 1n+remaining:
      do IO<Unit>:
        event : Window & ParagraphEvent <- LiveParagraph.next(window)
        LiveParagraph.finish_document(event, document,
          w => d => LiveParagraph.run_document(remaining, w, d, rest))

def LiveParagraph.workspace_blocked(window: Window, value: As.Workspace, rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    shown : Window <- LiveParagraph.status(window, "Save As is pending or uncertain. Keep this document open")
    rest(shown, value)

def LiveParagraph.workspace_ended(window: Window, decision: Control.EndDecision, rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match decision:
    case Control.CloseSafe{workspace}:
      LiveParagraph.close(window)
    case Control.Suspended{workspace}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Input ended. Unsaved document retained; resume is unavailable")
        Suspension.wait()
        rest(shown, workspace)

# This callback accepts only a session derived by finish_stored from the
# retained session. It is not an external session-replacement entry point.
def LiveParagraph.workspace_stored(update: Window & ParagraphEvent, +value: As.Workspace, current: App.Document,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match current:
    case App.Document{destination, session}:
      LiveParagraph.finish_stored(update, session,
        w => s => rest(w, As.updated(True{}, value, s)))

def LiveParagraph.workspace_completed(window: Window, result: Publish.Completion,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match result:
    case Publish.Completed{workspace, outcome}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, LiveParagraph.save_message(outcome))
        rest(shown, workspace)
    case Publish.NotStarted{workspace}:
      LiveParagraph.workspace_blocked(window, workspace, rest)

def LiveParagraph.workspace_candidate(window: Window, value: As.Workspace, choice: As.Candidate,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match choice:
    case As.Cancelled{}:
      rest(window, value)
    case As.Unavailable{}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save As target is unavailable or invalid. The document is retained")
        rest(shown, value)
    case As.Rejected{message}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save As stopped without overwriting a file: " ++ message)
        rest(shown, value)
    case choice:
      do IO<Unit>:
        result : Publish.Completion <- Publish.run_completion(As.start(value, choice))
        LiveParagraph.workspace_completed(window, result, rest)

def LiveParagraph.workspace_resolve_allowed(ok: Bool, window: Window, value: As.Workspace, requested: String,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match ok:
    case True{}:
      do IO<Unit>:
        choice : As.Candidate <- Target.resolve(requested)
        LiveParagraph.workspace_candidate(window, value, choice, rest)
    case False{}:
      LiveParagraph.workspace_blocked(window, value, rest)

def LiveParagraph.workspace_save_as(window: Window, value: As.Workspace, requested: String,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match value:
    case As.Editing{App.Document{destination, +session}}:
      LiveParagraph.workspace_resolve_allowed(Bool.not(Saving.pending(session)), window, value, requested, rest)
    case value:
      LiveParagraph.workspace_blocked(window, value, rest)

def LiveParagraph.workspace_picked(result: Window & SaveAsPick, value: As.Workspace,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match result:
    case (window, SaveAsSelected{requested}):
      LiveParagraph.workspace_save_as(window, value, requested, rest)
    case (window, SaveAsCancelled{}):
      rest(window, value)
    case (window, SaveAsPickerUnavailable{}):
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save As picker is unavailable on this host")
        rest(shown, value)

def LiveParagraph.workspace_pick_allowed(ok: Bool, window: Window, value: As.Workspace,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match ok:
    case True{}:
      do IO<Unit>:
        result : Window & SaveAsPick <- LiveParagraph.pick_save_as(window)
        LiveParagraph.workspace_picked(result, value, rest)
    case False{}:
      LiveParagraph.workspace_blocked(window, value, rest)

def LiveParagraph.workspace_choose(window: Window, value: As.Workspace,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match value:
    case As.Editing{App.Document{destination, +session}}:
      LiveParagraph.workspace_pick_allowed(Bool.not(Saving.pending(session)), window, value, rest)
    case value:
      LiveParagraph.workspace_blocked(window, value, rest)

def LiveParagraph.workspace_observed(window: Window, +value: As.Workspace,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match value:
    case As.Editing{document}:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save As confirmed")
        rest(shown, value)
    case value:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "Save As is still uncertain. Keep this document open")
        rest(shown, value)

def LiveParagraph.workspace_recheck(window: Window, value: As.Workspace,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match value:
    case As.Uncertain{document, target, id, snapshot}:
      do IO<Unit>:
        observed : As.Workspace <- Observe.run(value)
        LiveParagraph.workspace_observed(window, observed, rest)
    case value:
      do IO<Unit>:
        shown : Window <- LiveParagraph.status(window, "No uncertain Save As to recheck")
        rest(shown, value)

def LiveParagraph.workspace_finish(update: Window & ParagraphEvent, +value: As.Workspace,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match update value:
    case (window, ParagraphRecheckSaveAs{}) value:
      LiveParagraph.workspace_recheck(window, value, rest)
    case (window, ParagraphChooseSaveAs{}) value:
      LiveParagraph.workspace_choose(window, value, rest)
    case (window, ParagraphSaveAs{requested}) value:
      LiveParagraph.workspace_save_as(window, value, requested, rest)
    case (window, ParagraphDraftEnded{}) value:
      LiveParagraph.workspace_ended(window, Control.Suspended{value}, rest)
    case (window, ParagraphInputEnded{}) value:
      LiveParagraph.workspace_ended(window, Control.ended(value), rest)
    case update As.Editing{document}:
      LiveParagraph.finish_document(update, document,
        w => d => rest(w, As.Editing{d}))
    case (window, ParagraphSave{}) value:
      LiveParagraph.workspace_blocked(window, value, rest)
    case (window, ParagraphClosed{}) value:
      LiveParagraph.workspace_blocked(window, value, rest)
    case update value:
      LiveParagraph.workspace_stored(update, value, As.document(value), rest)

def LiveParagraph.workspace_run(fuel: Nat, window: Window, value: As.Workspace,
  rest: Window -> As.Workspace -> IO(Unit)) -> IO(Unit):
  match fuel:
    case 0n:
      rest(window, value)
    case 1n+remaining:
      do IO<Unit>:
        event : Window & ParagraphEvent <- LiveParagraph.next(window)
        LiveParagraph.workspace_finish(event, value, w => v => LiveParagraph.workspace_run(remaining, w, v, rest))

# Only this outer IO driver may repeat indefinitely. It is outside the pure
# LAWS imports. The checked finite pump still owns all save and close decisions.
@unsafe def LiveParagraph.drive_workspace(window: Window, workspace: As.Workspace) -> IO(Unit):
  LiveParagraph.workspace_run(1000n, window, workspace,
    w => v => LiveParagraph.drive_workspace(w, v))

def LiveParagraph.drive_document(window: Window, document: App.Document) -> IO(Unit):
  LiveParagraph.drive_workspace(window, As.Editing{document})

def LiveParagraph.start_document(value: Maybe<&2, Stored.Session>, destination: App.Destination) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Initial document is not valid UTF-8")
    case Some{+session}:
      match session:
        case Stored.Session{editor, storage}:
          do IO<Unit>:
            window : Window <- LiveParagraph.open(State.source(State.current(editor)))
            shown : Window <- LiveParagraph.present(window, editor)
            LiveParagraph.drive_document(shown, App.with_session(destination, session))

def LiveParagraph.start_stored(value: Maybe<&2, Stored.Session>) -> IO(Unit):
  LiveParagraph.start_document(value, App.Untitled{})

def LiveParagraph.start_bytes(value: Maybe<&2, List<&2, U32>>) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Initial document encoding failed")
    case Some{bytes}:
      LiveParagraph.start_stored(Stored.load(Save.open(bytes)))

def LiveParagraph.open_result(value: Open.Outcome) -> IO(Unit):
  match value:
    case Open.Opened{App.Document{destination, session}}:
      LiveParagraph.start_document(Some{session}, destination)
    case Open.Rejected{raw, reason}:
      match reason:
        case Open.InvalidUtf8{}:
          IO.die(Unit, 1, "Cannot open this file: its bytes are not valid UTF-8")
        case Open.TooLarge{}:
          IO.die(Unit, 1, "Cannot open this file: the current limit is 8 MiB")
        case Open.InvalidPath{}:
          IO.die(Unit, 1, "Cannot open this file: its resolved path is not valid UTF-8")
        case Open.InvalidIdentity{}:
          IO.die(Unit, 1, "Cannot open this file: its document identity is not valid")
    case Open.ReadFailed{requested, code, message}:
      IO.die(Unit, 1, "Cannot read this file: " ++ message)

def LiveParagraph.recovery_result(value: Recovery.Outcome) -> IO(Unit):
  match value:
    case Recovery.Opened{document, disk, catalog}:
      LiveParagraph.open_result(Open.Opened{document})
    case Recovery.Blocked{initial, plan}:
      IO.die(Unit, 1, "Cannot recover this file: the recovery catalog needs review")
    case Recovery.Unresolved{initial}:
      IO.die(Unit, 1, "Cannot recover this file: the initial destination is not resolved")

def LiveParagraph.recovery_config(value: RecoverySettings.Choice, initial: Initial.Initial) -> IO(Unit):
  match value initial:
    case RecoverySettings.Disabled{} Initial.Initial{document, disk}:
      LiveParagraph.open_result(Open.Opened{document})
    case RecoverySettings.Enabled{host, root} initial:
      do IO<Unit>:
        catalog : RecoveryScan.Outcome <- RecoveryScan.scan(host, root)
        LiveParagraph.recovery_result(Recovery.prepare(initial, catalog))
    case RecoverySettings.Invalid{message} _:
      IO.die(Unit, 1, "Cannot recover this file: " ++ message)
    case RecoverySettings.Unavailable{host, root} _:
      IO.die(Unit, 1, "Cannot recover this file: the process host is unavailable")

def LiveParagraph.initial_result(value: Initial.Outcome) -> IO(Unit):
  match value:
    case Initial.Opened{initial}:
      do IO<Unit>:
        config : Result<&1, &1, U32 & String,
          Bool & (Maybe<List<&2, U32>> & Maybe<List<&2, U32>>)> <- RecoveryConfig.read()
        LiveParagraph.recovery_config(RecoverySettings.decode(config), initial)
    case Initial.Failed{reason}:
      LiveParagraph.open_result(reason)

def LiveParagraph.open_config(value: Maybe<Maybe<String>>) -> IO(Unit):
  match value:
    case Some{Some{+path}}:
      do IO<Unit>:
        result : Initial.Outcome <- Reader.read(path)
        LiveParagraph.initial_result(result)
    case Some{None{}}:
      LiveParagraph.start_bytes(Utf8.encode("Edit this paragraph. 中文输入 and 日本語入力 are welcome."))
    case None{}:
      IO.die(Unit, 1, "Cannot open this file: the requested path is not valid UTF-8")

def main() -> IO(Unit):
  do IO<Unit>:
    path : Maybe<List<&2, U32>> <- Config.read_bytes()
    LiveParagraph.open_config(Config.decode(path))
