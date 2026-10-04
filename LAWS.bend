import Base
# The desktop WebView uses CodeMirror input/history and Rust file effects.
# These foreign contracts need integration checks. Existing native laws do not
# prove the new host. Bend still supplies source edit plans through WebCommands.
# Preview widgets never become the saved source record. MathJax parses TeX.
# Theme changes are presentation effects, outside the Bend proof boundary.
# They must not dispatch source edits or replace editor state.
# The Markdown math extension supplies ranges. Web tests check these contracts,
# source-mode history, HTML isolation, and removal of pending renderer results.
# Table cells have no separate history. Accepted edits patch the source record
# through CodeMirror. Outer history restores the exact source and cell text.
# Table structure commands validate source patches before changing the document.
# Web integration checks, not these Bend laws, cover their history and ranges.
# Selecting an omitted table cell leaves source unchanged. First accepted input
# materializes its required slots and text in one outer history transaction.
# Search uses normalized source, including hidden widget source. Replacement
# uses outer history. Search and outline commands defer during composition.
# Outline navigation changes selection without adding a history event.
# List and quote rendering retains source. A task toggle changes one validated
# marker character through outer history. Web integration checks cover these
# contracts, including exact Undo, composition guards, and source reveal.
# Formatting changes source through outer history. Parsed delimiter ranges and
# accepted inline syntax control patches. Integration checks cover these foreign
# contracts; the Bend laws do not prove CodeMirror formatting or parser behavior.
# Link forms capture source identity and a monotonic document generation.
# Apply/Remove revalidate the capture and input guards. Changed fields use one
# outer history transaction. Cancel changes no source. Foreign integration
# checks cover these contracts and exact reference-definition preservation.
import ./src/AppDocument.bend as AppDocument
import ./src/DocumentOpen.bend as DocumentOpen
import ./src/ResolvedOpen.bend as ResolvedOpen
import ./src/InitialOpen.bend as InitialOpen
import ./src/AppRecovery.bend as AppRecovery
import ./src/AppSave.bend as AppSave
import ./src/AppInput.bend as AppInput
import ./src/AppSaveAs.bend as AppSaveAs
import ./src/WorkspaceControl.bend as WorkspaceControl
import ./src/NewFileReconcile.bend as NewFileReconcile
import ./src/RecoverySettings.bend as RecoverySettings
import ./src/ListReturn.bend as ListReturn
import ./src/ReturnCommand.bend as ReturnCommand
import ./src/IndexedReturn.bend as IndexedReturn

import ./src/TextPosition.bend as Position
import ./src/Projection.bend as Projection
import ./src/DirectState.bend as State
import ./src/Experiment.bend as E
import ./src/CursorMap.bend as Cursor
import ./src/Blocks.bend as Blocks
import ./src/Document.bend as Document
import ./src/BlockScene.bend as Scene
import ./src/BlockIndex.bend as Index
import ./src/BlockSceneCache.bend as Cache
import ./src/SceneIndex.bend as Mapping
import ./src/SaveState.bend as Save
import ./src/RecoveryState.bend as Recovery
import ./src/RecoveryEntry.bend as Entry
import ./src/RecoveryLookup.bend as Lookup
import ./src/RecoveryScan.bend as Scan
import ./src/RecoveryPlan.bend as Plan
import ./src/Utf8.bend as Utf8
import ./src/RecoveryEditor.bend as RecoveryEditor
import ./src/ByteBuffer.bend as ByteBuffer
import ./src/TextByteMap.bend as TextByteMap
import ./src/TextStorage.bend as TextStorage
import ./src/PersistentSave.bend as PersistentSave
import ./src/StorageHistory.bend as StorageHistory
import ./src/StoredEditor.bend as StoredEditor
import ./src/StoredRecovery.bend as StoredRecovery
import ./src/ByteRelease.bend as ByteRelease
import ./src/TextRelease.bend as TextRelease
import ./src/SceneRelease.bend as SceneRelease
import ./src/EditorRelease.bend as EditorRelease
import ./src/ProjectionWidthProof.bend as WidthProof
import ./src/ProjectionWidthLongProof.bend as WidthLong
import ./src/ScalarText.bend as Scalar
import ./src/ListAppend.bend as Append

# These laws prove output equality. Runtime tests check allocation balance.
law indexed_owned_lines_preserves_source:
  for +source: String
  {IndexedReturn.owned_lines(source) == Blocks.lines(source) : List<&2, String>}

law projection_owned_mapping_preserves_points:
  for source: String
  for runs: List<&2, E.RenderRun>
  {Projection.mapping(source, runs) == Cursor.build(runs, Scalar.to_chars(source), 0n) : List<&2, Nat>}

law scene_owned_count_preserves_size:
  for +source: String
  {Scene.scan_count(source) == Document.count_scalars(source, 0n) : Nat}

law document_owned_prepend_preserves_source:
  for +text: String
  for +reversed: String
  {Document.prepend_owned(text, reversed) == Document.prepend_text(text, reversed) : String}

law cache_append_preserves_order:
  for -A: Data
  for +left: List<&2, A>
  for +right: List<&2, A>
  {Append.append(&2, A, left, right) == List.append(&2, A, left, right) : List<&2, A>}

# LAW: Omitting unused cursor positions preserves source width and remainder.
law projection_width_matches_consume:
  for +visible: List<&2, Char>
  for +chars: List<&2, Char>
  for +offset: Nat
  for +plain: Bool
  {Projection.consume_width(visible, chars, offset, plain) == WidthLong.width(Cursor.consume(visible, chars, offset, plain)) : Projection.Width}

# LAW: The width-only scan preserves the complete previous Part result.
law projection_part_matches_reference:
  for +run: E.RenderRun
  for +chars: List<&2, Char>
  {Projection.part(run, chars) == WidthProof.reference(run, chars) : Projection.Part}

# LAW: A failed disk observation cannot change the retained workspace.
law new_file_observation_retains_workspace:
  for +workspace: AppSaveAs.Workspace
  for id: Nat
  {NewFileReconcile.complete(workspace, id, NewFileReconcile.RetainUncertain{}) == workspace : AppSaveAs.Workspace}

# LAW: An uncertain Save As cannot enter ordinary Save.
law workspace_uncertain_blocks_save:
  for +document: AppDocument.Document
  for +target: AppSaveAs.Target
  for +id: Nat
  for +snapshot: ByteBuffer.Buffer
  {WorkspaceControl.save(AppSaveAs.Uncertain{document, target, id, snapshot}) == WorkspaceControl.SaveBlocked{AppSaveAs.Uncertain{document, target, id, snapshot}} : WorkspaceControl.SaveDecision}

# LAW: An uncertain Save As cannot authorize Close.
law workspace_uncertain_blocks_close:
  for +document: AppDocument.Document
  for +target: AppSaveAs.Target
  for +id: Nat
  for +snapshot: ByteBuffer.Buffer
  {WorkspaceControl.close(AppSaveAs.Uncertain{document, target, id, snapshot}) == WorkspaceControl.CloseBlocked{AppSaveAs.Uncertain{document, target, id, snapshot}} : WorkspaceControl.CloseDecision}

# LAW: Input ending retains the complete uncertain transaction.
law workspace_uncertain_input_retains:
  for +document: AppDocument.Document
  for +target: AppSaveAs.Target
  for +id: Nat
  for +snapshot: ByteBuffer.Buffer
  {WorkspaceControl.ended(AppSaveAs.Uncertain{document, target, id, snapshot}) == WorkspaceControl.Suspended{AppSaveAs.Uncertain{document, target, id, snapshot}} : WorkspaceControl.EndDecision}

# Runtime Save and Discard choices must come from the host. The first save host
# is synchronous: finish it before another choice. Pending tickets block normal
# close even when undo restores baseline bytes. These laws do not prove a disk
# operation, exclude concurrent writers, or supply a Windows service.
# EOF is not a close choice. Unavailable wake retains the complete document.
# These pure laws do not prove process liveness or survival after termination.
law app_save_as_cancel_keeps_workspace:
  for value: AppSaveAs.Workspace
  {AppSaveAs.start(value, AppSaveAs.Cancelled{}) == value : AppSaveAs.Workspace}

law app_save_as_uncertain_completion_keeps_transaction:
  for document: AppDocument.Document
  for target: AppSaveAs.Target
  for id: Nat
  for snapshot: ByteBuffer.Buffer
  for response: Nat
  for outcome: AppSave.Outcome
  {AppSaveAs.complete(AppSaveAs.Uncertain{document, target, id, snapshot}, response, outcome) ==
    AppSaveAs.Uncertain{document, target, id, snapshot} : AppSaveAs.Workspace}

law app_input_unavailable_retains_document:
  for document: AppDocument.Document
  {AppInput.resume(document, AppInput.Unavailable{}) ==
    AppInput.Retained{document} : AppInput.Continuation}

law app_input_keep_open_suspends_document:
  for document: AppDocument.Document
  {AppInput.from_close(AppSave.KeepOpen{document}) ==
    AppInput.Suspended{document} : AppInput.Ended}

law app_save_cancel_keeps_document:
  for document: AppDocument.Document
  {AppSave.choose_close(document, AppSave.CancelChoice{}) ==
    AppSave.KeepOpen{document} : AppSave.CloseDecision}

law app_save_failed_close_keeps_document:
  for document: AppDocument.Document
  {AppSave.close_completed(document, AppSave.OldKept{}) ==
    AppSave.KeepOpen{document} : AppSave.CloseDecision}

law app_save_uncertain_close_keeps_document:
  for document: AppDocument.Document
  {AppSave.close_completed(document, AppSave.Uncertain{}) ==
    AppSave.KeepOpen{document} : AppSave.CloseDecision}

law app_save_untitled_has_no_request:
  for session: StoredEditor.Session
  {AppSave.prepare(AppDocument.Document{AppDocument.Untitled{}, session}) ==
    AppSave.Unavailable{AppDocument.Document{AppDocument.Untitled{}, session}} : AppSave.Preparation}

# Complete-session release retains both unfinished halves and completes only
# when both queues finish. Its work budget applies to each half separately.
# Drain yields between steps. Fuel exhaustion returns the pending queue to the
# caller, which must keep it and continue. Test a delayed heartbeat, not dispatch
# time alone. Never treat dropping an unfinished queue as completion.
law editor_release_both_finished:
  {EditorRelease.progress(None{}, None{}) == EditorRelease.Complete{} : EditorRelease.Progress}

# Formatted document/scene release opens containers separately and consumes
# at most 128 scalars or points per text/list item. Never drop a whole run.
law scene_release_zero_keeps_queue:
  for item: SceneRelease.Item
  for rest: List<&2, SceneRelease.Item>
  {SceneRelease.step(0n, SceneRelease.Queue{item <> rest}) ==
    SceneRelease.Pending{SceneRelease.Queue{item <> rest}} : SceneRelease.Progress}

# Release both scalar-map roots and authoritative bytes. Keep pending work.
# History release must also queue current/saved/pending buffers and each undo
# and redo revision. Retain other live sessions. Clearing an identity is not
# confirmation of a save and must not write files.
law text_release_zero_keeps_queue:
  for item: TextRelease.Item
  for rest: List<&2, TextRelease.Item>
  {TextRelease.step(0n, TextRelease.Queue{item <> rest}) ==
    TextRelease.Pending{TextRelease.Queue{item <> rest}} : TextRelease.Progress}

# Byte release consumes its queue in bounded node steps. Valid leaf chunks
# contain at most 512 bytes. Never discard a pending queue on the UI path.
law byte_release_zero_keeps_queue:
  for tree: Index.Tree<ByteBuffer.Chunk>
  for rest: List<&2, Index.Tree<ByteBuffer.Chunk>>
  {ByteRelease.step(0n, ByteRelease.Queue{tree <> rest}) ==
    ByteRelease.Pending{ByteRelease.Queue{tree <> rest}} : ByteRelease.Progress}

# Exact byte comparison must reject unequal cached lengths before traversal.
# A checksum must never substitute for exact content comparison.
law byte_comparison_unequal_lengths:
  for left: Index.Tree<ByteBuffer.Chunk>
  for right: Index.Tree<ByteBuffer.Chunk>
  {ByteBuffer.equal_length(False{}, left, right) == False{} : Bool}

# Recovery must permit opening before persistent editor state is created.
# Keep the full plan if current bytes cannot be loaded. Do not write files.
# Persistent native restart checks must read the writer's durable record in a
# new process, use its real document identity, and retain both on-disk files.
law stored_recovery_failed_load_keeps_plan:
  for plan: Plan.Plan
  for requested: List<&2, U32>
  for catalog: Scan.Catalog
  {StoredRecovery.loaded(None{}, plan, requested, catalog) ==
    StoredRecovery.Blocked{plan} : StoredRecovery.Outcome}

# The formatted editor and byte storage must use the same mapped source range.
# Commit both histories only after storage validation. Selection is independent
# of stored bytes; undo and redo restore both histories together.
# Native input checks must compare the host source, persistent text, current
# bytes, saved baseline, and pending ticket after every committed event.
# Native timing must reach viewport layout/display before reference checks.
# Keep exact text validation outside the frame interval and retain snapshots.
# IME marked text stays in the host until composition commits.
law stored_editor_failed_replacement_keeps_session:
  for history: StorageHistory.Session
  for session: StoredEditor.Session
  for text: String
  {StoredEditor.replaced(StorageHistory.Rejected{history}, session, text) ==
    StoredEditor.Rejected{session} : StoredEditor.EditResult}

law stored_editor_failed_edit_keeps_session:
  for history: StorageHistory.Session
  for session: StoredEditor.Session
  for start: Nat
  for end: Nat
  for text: String
  {StoredEditor.edited(StorageHistory.Rejected{history}, session, start, end, text) ==
    StoredEditor.Rejected{session} : StoredEditor.EditResult}

# History stores complete text snapshots. Undo and redo change current bytes
# only. Save completion must not rewrite history. Failed edits keep all roots.
# Snapshot identifiers are local to one session and are never read from disk.
# Undo retains the next identifier. A matching saved identifier proves clean;
# different identifiers must fall back to exact bytes, not prove dirty.
law storage_history_known_snapshot_is_clean:
  for save: PersistentSave.State
  {StorageHistory.known_dirty(True{}, save) == False{} : Bool}

# Clearing history retains current text, save state, and revision allocation.
# Deferred release owns its completion channel. Join it before shutdown.
# A fast dispatch is insufficient: check a delayed heartbeat while release runs.
law storage_history_clear_preserves_current:
  for current: TextStorage.Snapshot
  for undo: List<&2, StorageHistory.Revision>
  for redo: List<&2, StorageHistory.Revision>
  for save: PersistentSave.State
  for identity: StorageHistory.Identity
  {StorageHistory.clear_history(StorageHistory.Session{current, undo, redo, save, identity}) ==
    StorageHistory.Session{current, Nil{}, Nil{}, save, identity} : StorageHistory.Session}

law storage_history_failed_edit_keeps_session:
  for snapshot: TextStorage.Snapshot
  for session: StorageHistory.Session
  {StorageHistory.edited(TextStorage.Rejected{snapshot}, session) ==
    StorageHistory.Rejected{session} : StorageHistory.EditResult}

# Save requests retain byte-tree roots. Edits must not replace the saved
# baseline or pending ticket. An uncertain result must keep the entire state.
# Recovery record boundaries may flatten snapshots. Loading must reject any
# value above 255 in current, saved, or pending bytes without partial success.
# Valid raw bytes, including invalid UTF-8, must survive record round trips.
law persistent_save_uncertain_keeps_state:
  for state: PersistentSave.State
  for id: Nat
  {PersistentSave.complete(state, id, Save.ReplacementUncertain{}) == state : PersistentSave.State}

law persistent_save_unsynced_keeps_state:
  for state: PersistentSave.State
  for id: Nat
  for observed: ByteBuffer.Buffer
  {PersistentSave.reconcile(state, id, observed, False{}) == state : PersistentSave.State}

# Text storage pairs authoritative bytes with a scalar mapping cache. Scalar
# edits must update both roots together and encode only inserted text. A failed
# update must return the original snapshot rather than partial new storage.
law text_storage_failed_mapping_keeps_snapshot:
  for original: TextStorage.Snapshot
  for insert: Maybe<&2, List<&2, U32>>
  for start: Maybe<&2, Nat>
  for end: Maybe<&2, Nat>
  {TextStorage.edited(original, None{}, insert, start, end) ==
    TextStorage.Rejected{original} : TextStorage.EditResult}

# UTF-8 byte mapping uses source scalar positions, not native UTF-16 positions.
# Cached scalar and byte trees must contain matching spans. Spans hold at most
# 128 valid scalars. Mapping updates must preserve older saved/pending roots.
law text_byte_mapping_rejects_invalid_text:
  for text: String
  {TextByteMap.from_gate(False{}, text) == None{} : Maybe<&2, TextByteMap.Mapping>}

# Scalar edits must rebuild only boundary spans and inserted text. They must
# preserve unchanged spans and old roots. Clamp and reversed-range semantics
# must match the source editor. Reject invalid inserted text before replacement.
law text_byte_invalid_replacement_is_rejected:
  for map: TextByteMap.Mapping
  for first: Nat
  for removed: Nat
  {TextByteMap.added_range(None{}, map, first, removed) ==
    None{} : Maybe<&2, TextByteMap.Mapping>}

# Persistent byte edits must preserve saved and pending snapshots. Store raw
# bytes exactly, including invalid UTF-8. Byte positions differ from scalar and
# UTF-16 positions. Leaf byte lists must stay at most 512 bytes long.
law byte_buffer_invalid_input_is_rejected:
  for bytes: List<&2, U32>
  {ByteBuffer.from_gate(False{}, bytes) == None{} : Maybe<&2, ByteBuffer.Buffer>}

# Text conversion must preserve valid UTF-8 bytes, including NUL, BOM, CRLF,
# and combining marks. Invalid bytes must not become replacement characters.
# Keep original recovery bytes if decoding fails. Do not open them as empty text.
law utf8_incomplete_is_rejected:
  for code: U32
  for minimum: U32
  for reversed: String
  {Utf8.finish(Utf8.Decoder{1, code, minimum, reversed, True{}}) ==
    None{} : Maybe<&2, String>}

# A failed text decode must retain the complete recovery plan. A restored edit
# opens with its observed disk baseline, not with its current edit as saved.
# Opening recovery starts a new editor model; it does not invent undo history.
law recovery_editor_invalid_text_keeps_plan:
  for plan: Plan.Plan
  for requested: List<&2, U32>
  for catalog: Scan.Catalog
  for save: Save.State
  {RecoveryEditor.decoded(None{}, plan, requested, catalog, save) ==
    RecoveryEditor.Blocked{plan} : RecoveryEditor.Outcome}

law recovery_editor_invalid_edit_keeps_models:
  for previous: RecoveryEditor.Outcome
  for requested: List<&2, U32>
  for catalog: Scan.Catalog
  for save: Save.State
  for attempted: State.Session
  {RecoveryEditor.encoded(None{}, previous, requested, catalog, save, attempted) ==
    RecoveryEditor.RejectedEdit{previous, attempted} : RecoveryEditor.Outcome}

# Edit, undo, and redo must synchronize current save bytes with editor source.
# Selection must not change save state. Pending save tickets keep their exact
# requested snapshots while later edits change current bytes. Completion may
# update the saved baseline but must not replace those later edits.
# Native recovery event checks must compare the host source with Bend source
# and current save bytes after each committed event. Marked text is temporary
# until the native host commits it. Keep the saved baseline and pending ticket.
# Native restart checks must obtain document identity and source bytes from the
# actual source file and scan the catalog left by the stopped writer. Native
# edits must not write either file unless an explicit save operation is run.
# Event performance measurements must include synchronization with save bytes.
# Fast document edits alone do not establish the complete 16 ms frame target.

# Recovery readers must ignore incomplete temporary journal files. Only a
# validated complete record may restore the edit. Journal replacement must
# retain the previous complete record until rename. Foreign interruption and
# restart checks belong in tests/journal_interruption.sh.
# Recovery encoding must preserve every byte, including NUL and invalid UTF-8.
# Version 2 uses lowercase hexadecimal bytes. Readers must also accept valid
# version 1 records. A checksum does not replace payload validation.
# Recovery restart checks must use separate processes and actual disk bytes.
# An oversized host save must fail before it creates a pending replacement.
# Journal interruption checks must also cover one-MiB current, saved, and
# pending snapshots. Restart must retain the correct complete edit version.
# An external disk change that matches neither saved nor pending bytes must
# retain the complete recorded state and disk bytes as a conflict. Matching
# the current edit alone does not establish a confirmed saved baseline.
# Large version 2 recovery traversals must use tail calls or bounded call depth.
# Native success alone does not establish JavaScript large-record behavior.
# Large file recovery must also be checked through JavaScript file effects.
# Codec round trips alone do not establish disk or process-restart behavior.
# A recovery entry belongs to one exact, nonempty host-supplied identity.
# Equal saved bytes do not establish document identity. Rejection must retain
# the complete entry and observed disk bytes. Host identity assignment and
# filesystem lookup remain outside this pure boundary.
# Persisted entry checks must use separate processes and two actual files with
# identical saved bytes. Every reader must check the persisted identity and
# complete state before selecting a recovery outcome.
# PATH1 identities name existing resolved save destinations. Atomic file
# replacement at that destination must keep its identity. The core must not
# interpret an identity as a path or use saved-byte equality as identity.
# Path spelling follows the host filesystem. Do not force case or Unicode
# normalization in the Bend core. Distinct hard-link save destinations keep
# separate PATH1 identities; replacing one must not change the other file.
# Lookup must compare exact identities. Duplicate ownership is ambiguous even
# when state bytes are equal. Preserve all matching entries for review. Missing
# means no match in validated candidates; it does not establish absent disk data.
# Directory effects must report unsupported entries and mark complete listings.
# Failed scans cannot establish missing recovery data. Candidate reads must stay
# under the opened root and reject symbolic links, non-files, and oversized data.
# The host returns bytes; Bend validates record ownership and contents.
# Scan rejection must retain each candidate name and reason. Read failures and
# invalid record contents are distinct. Root and listing failures must not
# return a successful empty catalog. Scanning must not rewrite any candidate.
# A listing above the host output bound must fail without a completion marker.
# The Bend scan must reject that failure and preserve the candidate namespace.
# Scan failures are values, not process exits. Keep the root and failure kind.
# Process transport failures retain their code and message. A later scan must
# remain possible in the same process after a failed scan.
# A successful scan must keep every accepted origin. Duplicate identities must
# stay ambiguous when the catalog contains many matching records.
# Connected restart checks must use host document identities, stored catalog
# bytes, and actual source-file reads. Equal file contents do not imply equal
# ownership. External source changes must remain available as conflicts.
# Catalog restart experiments must read the catalog record stored by the
# stopped writer. Do not copy the record into its catalog after that stop.

law recovery_scan_keeps_read_error:
  for code: U32
  for text: String
  for name: String
  {Scan.read_gate(False{}, code, text, name) ==
    Scan.Bad{Scan.Rejected{name, Scan.ReadFailed{code}}} : Scan.Item}

# Rejected entries can hide document ownership. Keep the whole catalog and
# stable disk bytes for review; do not treat a partial validated set as complete.
law recovery_plan_incomplete_requires_review:
  for catalog: Scan.Catalog
  for selection: Lookup.Selection
  for requested: List<&2, U32>
  for disk: List<&2, U32>
  {Plan.selected(False{}, catalog, selection, requested, disk) ==
    Plan.Review{catalog, selection, disk} : Plan.Decision}

law recovery_scan_keeps_invalid_origin:
  for name: String
  {Scan.decoded(None{}, name) ==
    Scan.Bad{Scan.Rejected{name, Scan.InvalidRecord{}}} : Scan.Item}

law recovery_lookup_retains_duplicates:
  for first: Entry.Entry
  for second: Entry.Entry
  for rest: List<&2, Entry.Entry>
  {Lookup.classify(first <> second <> rest) ==
    Lookup.Ambiguous{first <> second <> rest} : Lookup.Selection}

law invalid_lookup_keeps_candidates:
  for entries: List<&2, Entry.Entry>
  for requested: List<&2, U32>
  {Lookup.lookup_gate(False{}, entries, requested) ==
    Lookup.InvalidIdentity{requested, entries} : Lookup.Selection}

law recovery_entry_mismatch_keeps_versions:
  for entry: Entry.Entry
  for disk: List<&2, U32>
  {Entry.select(False{}, entry, disk) == Entry.WrongDocument{entry, disk} : Entry.Decision}

law recovery_conflict_keeps_versions:
  for recorded: Save.State
  for disk: List<&2, U32>
  {Recovery.restore_known(False{}, recorded, disk) ==
    Recovery.Conflict{recorded, disk} : Recovery.Decision}

law recovery_keeps_current_bytes:
  for current: List<&2, U32>
  for saved: List<&2, U32>
  for next: Nat
  for pending: Maybe<&2, Save.Ticket>
  for disk: List<&2, U32>
  {Recovery.restore_known(True{}, Save.State{current, saved, next, pending}, disk) ==
    Recovery.Restored{Save.State{current, disk, next, None{}}} : Recovery.Decision}

law unrecognized_save_keeps_state:
  for state: Save.State
  for id: Nat
  {Save.reconcile_equal(False{}, False{}, state, id) == state : Save.State}

law unsynced_save_keeps_state:
  for state: Save.State
  for id: Nat
  for observed: List<&2, U32>
  {Save.reconcile(state, id, observed, False{}) == state : Save.State}

law uncertain_save_keeps_state:
  for state: Save.State
  for id: Nat
  {Save.complete(state, id, Save.ReplacementUncertain{}) == state : Save.State}

law save_request_keeps_pending:
  for current: List<&2, U32>
  for saved: List<&2, U32>
  for next: Nat
  for ticket: Save.Ticket
  {Save.request(Save.State{current, saved, next, Some{ticket}}) ==
    Save.State{current, saved, next, Some{ticket}} : Save.State}

law save_failure_keeps_baseline:
  for current: List<&2, U32>
  for saved: List<&2, U32>
  for next: Nat
  for bytes: List<&2, U32>
  {Save.accept(False{}, current, saved, next, bytes) ==
    Save.State{current, saved, next, None{}} : Save.State}

law save_success_keeps_current:
  for current: List<&2, U32>
  for saved: List<&2, U32>
  for next: Nat
  for bytes: List<&2, U32>
  {Save.accept(True{}, current, saved, next, bytes) ==
    Save.State{current, bytes, next, None{}} : Save.State}

law stale_save_keeps_pending:
  for ok: Bool
  for current: List<&2, U32>
  for saved: List<&2, U32>
  for next: Nat
  for ticket: Save.Ticket
  {Save.result_matches(False{}, ok, current, saved, next, ticket) ==
    Save.State{current, saved, next, Some{ticket}} : Save.State}

# Scene range updates use block counts. Preserve the order and local cursor
# maps of retained chunks. Cached lengths and heights must remain correct.
# tests/SceneSpliceCheck.bend compares range updates with complete builds and
# checks balance, hidden blocks, UTF-16 positions, and repeated insertion.
# Direct edits splice the parser interval before refreshing selection ranges.
# Selection changes outside the parser interval must also refresh their chunks.
# Move the old selection's block ranks with retained prefix and suffix blocks.
# Include both blocks at a shared source boundary. Local refresh must not scan
# document blocks outside the parser and previous/new selection ranges.
# Scene index chunks retain local runs as well as local position maps.
# tests/SceneRangeCheck.bend checks exact one-MiB scenes and visited block counts.
# Scene patch rule: apply patches in list order. Each block range and UTF-16
# range refers to the scene after the preceding patch. Preserve other chunks.
# Patch payloads contain only affected chunks. Do not build complete host lists
# for local edits. Full presentation establishes a new host chunk baseline.
# Fresh chunks replace cached runs; prune discarded identifiers only after
# retaining identifiers used by replacement chunks. Empty blocks still count.
# tests/HostPatchCheck.bend replays patches and checks exact ranges and styles.
# Native, POSIX, and JavaScript checks cover patches and complete presentation.
# Native storage patches must account for the pending input replacement.
# A containing patch consumes that replacement; earlier patches move its range.
# Unknown baselines and partial overlaps require complete comparison.
# Native host checks compare text and attributes with a complete projection.
# A native scene patch may retain matching edges only after checking both text
# and attributes in the current preview. Keep UTF-16 surrogate pairs complete.
# Use this comparison only when no native input edit awaits projection. Keep
# the full Bend patch, rendered scene, chunk identifiers, and order unchanged.
# Native input may use one valid text-storage range. Trim unchanged text within
# that range, then expand both replacements to complete composed characters.
# Multiple storage edits or an unknown baseline require complete input comparison.
# Native source-position conversion uses a balanced index with scalar and UTF-16
# lengths. Leaves contain at most 512 UTF-16 units and never split a surrogate
# pair. Edits share retained branches; complete source changes rebuild the index.
# Host checks verify balance, exact source reconstruction, and every cursor rank.
# Track whether the native source field matches Bend. Independent character
# edits clear that baseline; attributes do not. Bend updates restore it without
# sending input events. An unknown baseline requires complete source restoration.
# Native text layout may use separate regions. Final projection must keep the
# caret visible. Native document checks verify its glyph bounds after every edit
# and verify scrolling near the start, middle, and end after complete layout.
# Native input checks must also run without a complete-layout scroll before the
# first edit. Keep exact source, cursor, cache, and visible-caret checks on that path.
# Complete scene rendering may fork independent document-tree branches. Derive
# each branch's source offset from cached prefix lengths and preserve list order.
# Parallel and sequential scans must have identical entries, chunks, styles,
# freshness flags, positions, and reuse counts. Small regions stay sequential.
# Large empty caches may be built by identifier-bit partitions. Their tree,
# entry count, and lookup results must match sequential insertion. Keep the last
# update for duplicate identifiers. Existing caches use incremental insertion.
# Fork only large identifier partitions; small partitions build sequentially.
# Prepare keys and their maximum in one accumulator pass. Partition accumulators
# must restore input order before recursion, so duplicate entries keep their last
# update. Do not retain a second walk over the complete update list.
# Native chunks may assemble plain text before applying style ranges. Preserve
# every run's exact UTF-16 range and attributes, including empty runs. Keep cached
# chunks immutable. Host checks compare multi-run chunks with single-run output.
# Native navigation must preserve source and exact source/native selections.
# Native selection events must retain selection affinity at wrapped boundaries
# when the source-to-scene mapping leaves the native selection range unchanged.
# Arrow movement must not stop inside an emoji surrogate pair, combining sequence,
# or joined emoji. Resizing the edit surface must retain selection and show the
# caret. Native event checks cover long wrapped text and repeated navigation.
law empty_scene_range_update:
  {Mapping.splice(Mapping.Empty{}, 8n, 10n, Nil{}) == Mapping.Empty{} : Mapping.Tree}

def empty_scene_range_update():
  {==}

# Source ranks include hidden blocks; native width cannot locate a source edit.
law scene_rank_hidden_block:
  {Mapping.rank(Mapping.build([
    Mapping.chunk(Scene.build("a", 2n, 2n), 1n, 0n, 2n, 2n),
    Mapping.chunk(Scene.build("```\n```\n", 9n, 9n), 8n, 1n, 9n, 9n),
    Mapping.chunk(Scene.build("b", 2n, 2n), 1n, 2n, 2n, 2n)
  ]), 5n, 0n) == 1n : Nat}

def scene_rank_hidden_block():
  {==}

law hidden_block_patch_range:
  {Cache.patch_cut(1n, 1n, Mapping.split(Mapping.build([
    Mapping.chunk(Scene.build("a", 2n, 2n), 1n, 0n, 2n, 2n),
    Mapping.chunk(Scene.build("```\n```\n", 9n, 9n), 8n, 1n, 9n, 9n),
    Mapping.chunk(Scene.build("b", 2n, 2n), 1n, 2n, 2n, 2n)
  ]), 1n), Nil{}) == Scene.HostPatch{1n, 1n, 1n, 0n, Nil{}} : Scene.HostPatch}

def hidden_block_patch_range():
  {==}

# Native memory rule: tests/memory.sh must keep 20 one-MiB parse/edit cycles
# below 200 MiB process peak memory. This is a measured gate, not a heap proof.
# History memory rule: tests/session_memory.sh checks 20 one-MiB edits and all
# undo/redo states below 300 MiB process peak memory. It includes scene caches and
# exact source materialization. This is separate from the editor idle target.
# Native benchmark rule: check every source character and cursor after each edit.
# Reference checks must not retain complete expected sources for prior edits.
# Stage clocks are optional; normal frame measurements keep them disabled.
# Scene transfer rule: the batch effect preserves run order, exact text, and
# all style codes. Consuming shared runs must not change the cached Bend scene.
# Host checks compare single and batch output; native event tests reuse scenes.
# Native block reuse rule: a fresh block replaces any cached block with the same
# identifier. Missing entries rebuild from the supplied runs. Keep only current
# blocks; legacy scene presentation clears the native block cache.
# Host source range rule: positions count Unicode scalars, with reversed and
# out-of-range positions handled as TextPosition.replace. Direct edits transmit
# only inserted text and source positions. Selection changes do not change source.
# Native event checks compare the host and raw editor with the exact Bend source.
law host_chunks_active_heading:
  {Scene.text(Cache.host_scene(Cache.render(Document.parse("# h\n\n**b**"),
    0n, 0n, Cache.empty()))) == "# h\n\nb" : String}

# The changed interval includes the parser anchor, which can be unchanged.
law changed_block_interval:
  {Document.interval(Document.apply_change(Document.parse("# a\n\n# b\n\n# c\n"),
    7n, 8n, "B")) == (1n, (2n, 2n)) : Nat & (Nat & Nat)}

law host_chunks_active_strong:
  {Scene.text(Cache.host_scene(Cache.render(Document.parse("# h\n\n**b**"),
    10n, 10n, Cache.empty()))) == "h\n\n**b**" : String}

# Native patch rule: a retained middle section must have equal text and requested
# attributes in both scenes. Split updates must match a full native projection.
# tests/host_roundtrip.c checks this foreign effect outside the Bend proof boundary.
law index_empty_prefix:
  for +tree: Index.Tree<Nat>
  {Index.concat(Nat, Index.Empty{}, tree) == tree : Index.Tree<Nat>}

law index_pair_length:
  for +a: Nat
  for +b: Nat
  for +x: Nat
  for +y: Nat
  {Index.length(Nat, Index.node(Nat, Index.Leaf{a, x}, Index.Leaf{b, y}))
    == Nat.add(x, y) : Nat}

# LAW: Local points move with their block without changing run text or styles.
law cached_points_shift:
  for +runs: List<&2, Scene.Run>
  for +x: Nat
  for +y: Nat
  for +offset: Nat
  {Cache.shift(Scene.Scene{runs, [x, y]}, offset)
    == Scene.Scene{runs, [Nat.add(offset, x), Nat.add(offset, y)]} : Scene.Scene}

# LAW: Reusing a cached projection keeps the full-build result in this fixture.
law cached_repeat_scene:
  {Cache.scene(Cache.render(Document.parse("# h\n\n**ab**"), 0n, 0n,
    Cache.cache(Cache.render(Document.parse("# h\n\n**ab**"), 0n, 0n, Cache.empty()))))
    == Scene.build("# h\n\n**ab**", 0n, 0n) : Scene.Scene}

# LAW: A surrogate position at a chunk end uses the next chunk's source boundary.
law indexed_surrogate_boundary:
  {Mapping.to_source(Mapping.build([
    Mapping.chunk(Scene.Scene{[Scene.Run{"😀", 0}], [0n, 1n]}, 1n, 0n, 0n, 0n),
    Mapping.chunk(Scene.Scene{[Scene.Run{"x", 0}], [2n, 3n]}, 3n, 1n, 4n, 4n)
  ]), 1n) == 3n : Nat}

# LAW: Hidden source positions map to the following visible boundary.
law indexed_hidden_source_boundary:
  {Mapping.to_native(Mapping.build([
    Mapping.chunk(Scene.Scene{[Scene.Run{"😀", 0}], [0n, 1n]}, 1n, 0n, 0n, 0n),
    Mapping.chunk(Scene.Scene{[Scene.Run{"x", 0}], [2n, 3n]}, 3n, 1n, 4n, 4n)
  ]), 2n) == 2n : Nat}

# LAW: Empty undo history keeps the current projection cache.
law empty_undo_keeps_view:
  for +snapshot: State.Snapshot
  for +redo: List<&2, State.Snapshot>
  for +view: State.RawView
  for cache: Cache.Cache
  for index: Mapping.Tree
  {State.raw_view(State.undo(State.Session{snapshot, Nil{}, redo, view, cache, index})) == view : State.RawView}

# LAW: Empty redo history keeps the current projection cache.
law empty_redo_keeps_view:
  for +snapshot: State.Snapshot
  for +undo: List<&2, State.Snapshot>
  for +view: State.RawView
  for cache: Cache.Cache
  for index: Mapping.Tree
  {State.raw_view(State.redo(State.Session{snapshot, undo, Nil{}, view, cache, index})) == view : State.RawView}

# LAW: A direct edit refreshes the scene and visible text together.
law edited_view_matches_source:
  {State.view(State.edit(State.start("**ab** xyz"), 8n, 8n, "😀")) == State.View{
    Scene.build("**ab** x😀yz", 9n, 9n),
    Scene.text(Scene.build("**ab** x😀yz", 9n, 9n))
  } : State.View}

# LAW: Backspace immediately after an insert restores the buffer.
law insert_then_backspace:
  for +byte: U32
  for +left: List<&2, U32>
  for +right: List<&2, U32>
  {E.Buffer.backspace(
    E.Buffer.insert(byte, E.Buffer{left, right})
  ) == Some{E.Buffer{left, right}} : Maybe<&2, E.Buffer>}

# LAW: A left move followed by a right move restores a buffer with a left byte.
law left_then_right:
  for +byte: U32
  for +left: List<&2, U32>
  for +right: List<&2, U32>
  {E.Buffer.move_right(
    E.Buffer.move_left(E.Buffer{byte <> left, right})
  ) == E.Buffer{byte <> left, right} : E.Buffer}

# LAW: Active strong text shows the exact Markdown source.
law active_strong_is_source:
  for +text: List<&2, U32>
  {E.Strong.view(True{}, E.Strong{text})
    == E.Strong.source(E.Strong{text}) : List<&2, U32>}

# LAW: Inactive strong text hides its Markdown marks but keeps its content.
law inactive_strong_is_content:
  for +text: List<&2, U32>
  {E.Strong.view(False{}, E.Strong{text})
    == text : List<&2, U32>}

# LAW: A cursor at the start does not change the exact source byte sequence.
law empty_left_source:
  for +right: List<&2, U32>
  {E.Buffer.source(E.Buffer{Nil{}, right}) == right : List<&2, U32>}

# LAW: Active formatting keeps every source point explicit.
law active_point_is_expanded:
  for +content_length: Nat
  for +point: E.StrongPoint
  {E.Strong.project(True{}, content_length, point)
    == E.Expanded{point} : E.ProjectedPoint}

# LAW: Inactive opening marks map to the start of visible text.
law inactive_opening_is_start:
  for +content_length: Nat
  for +second: Bool
  {E.Strong.project(False{}, content_length, E.Opening{second})
    == E.Text{0n} : E.ProjectedPoint}

# LAW: Inactive closing marks map to the end of visible text.
law inactive_closing_is_end:
  for +content_length: Nat
  for +second: Bool
  {E.Strong.project(False{}, content_length, E.Closing{second})
    == E.Text{content_length} : E.ProjectedPoint}

# LAW: Hiding marks does not move a position inside the strong text.
law inactive_content_keeps_offset:
  for +content_length: Nat
  for +offset: Nat
  {E.Strong.project(False{}, content_length, E.Content{offset})
    == E.Text{offset} : E.ProjectedPoint}

# LAW: A host commit does not normalize or replace paragraph text.
law paragraph_commit_preserves_text:
  for +text: String
  {E.Paragraph.commit(text) == text : String}

# LAW: Undo after a new commit restores the prior paragraph text.
law undo_after_apply_restores_text:
  for +present: String
  for +next: String
  for +undo: List<&2, String>
  for +redo: List<&2, String>
  {E.History.current(E.History.undo(E.History.apply(
    next, E.History{present, undo, redo}
  ))) == present : String}

# LAW: Redo after that undo restores the newly committed paragraph text.
law redo_after_undo_restores_text:
  for +present: String
  for +next: String
  for +undo: List<&2, String>
  for +redo: List<&2, String>
  {E.History.current(E.History.redo(E.History.undo(E.History.apply(
    next, E.History{present, undo, redo}
  )))) == next : String}

# LAW: A new commit clears the redo path.
law apply_clears_redo:
  for +present: String
  for +next: String
  for +undo: List<&2, String>
  for +redo: List<&2, String>
  {E.History.redo_count(E.History.apply(
    next, E.History{present, undo, redo}
  )) == 0n : Nat}

# LAW: Undo with no prior state leaves the full history unchanged.
law undo_without_prior_is_stable:
  for +present: String
  for +redo: List<&2, String>
  {E.History.undo(E.History{present, Nil{}, redo})
    == E.History{present, Nil{}, redo} : E.History}

# LAW: Projection never changes the Markdown source.
law projection_preserves_source:
  for +active: Bool
  for +source: String
  {E.Projection.source(E.Markdown.project(active, source)) == source : String}

# LAW: Active projection displays the exact Markdown source.
law active_projection_shows_source:
  for +source: String
  {E.Projection.view(E.Markdown.project(True{}, source)) == source : String}

# LAW: The first inactive strong example hides both pairs of marks.
law inactive_projection_hides_strong_marks:
  {E.Projection.view(E.Markdown.project(False{}, "**bold**"))
    == "bold" : String}

# LAW: An unfinished strong span remains visible for editing.
law inactive_projection_keeps_unclosed_marks:
  {E.Projection.view(E.Markdown.project(False{}, "**bold"))
    == "**bold" : String}

# LAW: One strong span does not prevent a later span from projecting.
law inactive_projection_hides_multiple_spans:
  {E.Projection.view(E.Markdown.project(False{}, "**one** + **two**"))
    == "one + two" : String}

# LAW: A single star is ordinary visible text.
law inactive_projection_keeps_single_star:
  {E.Projection.view(E.Markdown.project(False{}, "a*b"))
    == "a*b" : String}

# LAW: A complete whole-paragraph strong span exposes its content for rendering.
law whole_strong_finds_content:
  {E.Markdown.whole_strong("**bold**") == Some{"bold"} : Maybe<&2, String>}

# LAW: An unfinished whole-paragraph span is not rendered as strong.
law whole_strong_rejects_unclosed:
  {E.Markdown.whole_strong("**bold") == None{} : Maybe<&2, String>}

# LAW: Mixed text becomes three renderer segments without Markdown marks.
law first_strong_splits_mixed_text:
  {E.Markdown.first_strong("before **bold** after")
    == E.RenderFirstStrong{"before ", "bold", " after"}
    : E.FirstStrongRender}

# LAW: An unfinished mixed span stays plain and keeps its source marks.
law first_strong_keeps_unclosed_text:
  {E.Markdown.first_strong("before **bold")
    == E.RenderPlain{"before **bold"} : E.FirstStrongRender}

# LAW: The scalable renderer keeps every plain and strong run in reading order.
law render_runs_support_multiple_strong_spans:
  {E.Markdown.render_runs("one **two** three **four**") == [
    E.PlainRun{"one "},
    E.StrongRun{"two"},
    E.PlainRun{" three "},
    E.StrongRun{"four"}
  ] : List<&2, E.RenderRun>}

# LAW: An unfinished span becomes one plain run with its marks restored.
law render_runs_restore_unclosed_span:
  {E.Markdown.render_runs("one **two") == [
    E.PlainRun{"one **two"}
  ] : List<&2, E.RenderRun>}

# LAW: Plain, emphasis, and strong runs keep their reading order.
law render_runs_mix_emphasis_and_strong:
  {E.Markdown.render_runs("中文 *italic*\n**bold**") == [
    E.PlainRun{"中文 "}, E.EmphasisRun{"italic"},
    E.PlainRun{"\n"}, E.StrongRun{"bold"}
  ] : List<&2, E.RenderRun>}

# LAW: An unfinished emphasis span keeps its source marks visible.
law render_runs_restore_unclosed_emphasis:
  {E.Markdown.render_runs("one *two") == [E.PlainRun{"one *two"}]
    : List<&2, E.RenderRun>}

# LAW: A finished emphasis span does not consume an unfinished later span.
law render_runs_keep_later_unclosed_emphasis:
  {E.Markdown.render_runs("*one* and *two") == [
    E.EmphasisRun{"one"}, E.PlainRun{" and *two"}
  ] : List<&2, E.RenderRun>}

# LAW: Inline code keeps emphasis marks literal.
law render_runs_keep_code_literal:
  {E.Markdown.render_runs("`**literal**` *italic* **bold**") == [
    E.CodeRun{"**literal**"}, E.PlainRun{" "}, E.EmphasisRun{"italic"},
    E.PlainRun{" "}, E.StrongRun{"bold"}
  ] : List<&2, E.RenderRun>}

# LAW: Unfinished inline code keeps its opening mark.
law render_runs_restore_unclosed_code:
  {E.Markdown.render_runs("中文 `**literal**") == [
    E.PlainRun{"中文 `**literal**"}
  ] : List<&2, E.RenderRun>}

# LAW: Escaped asterisks and backticks in plain text remain literal.
law render_runs_keep_escaped_marks:
  {E.Markdown.render_runs("\\*literal\\* \\`code\\`") == [
    E.PlainRun{"*literal* `code`"}
  ] : List<&2, E.RenderRun>}

# LAW: Mixed visible positions refer to their exact source characters.
law cursor_map_mixed_runs:
  {Cursor.mapping("a **bc** *d* `e`") == [0n, 1n, 4n, 5n, 8n, 10n, 12n, 14n, 16n]
    : List<&2, Nat>}

# LAW: Unicode scalars and newline each occupy one position in this map.
law cursor_map_unicode_and_escape:
  {Cursor.mapping("中文\\*\n") == [0n, 1n, 3n, 4n, 5n] : List<&2, Nat>}

# LAW: Unfinished marks stay editable at their original source positions.
law cursor_map_unfinished_span:
  {Cursor.mapping("**a\\*") == [0n, 1n, 2n, 3n, 4n, 5n] : List<&2, Nat>}

# LAW: Hidden opening marks map to the first visible boundary.
law cursor_map_hidden_opening:
  {Cursor.to_view(Cursor.mapping("**ab**"), 1n) == 0n : Nat}

# LAW: Hidden closing marks map to the final visible boundary.
law cursor_map_hidden_closing:
  {Cursor.to_view(Cursor.mapping("**ab**"), 5n) == 2n : Nat}

# LAW: View positions beyond the end clamp to the source end.
law cursor_map_clamps_view:
  {Cursor.to_source(Cursor.mapping("**ab**"), 100n) == 6n : Nat}

# LAW: A mapped content position returns to the same visible position.
law cursor_map_content_roundtrip:
  {Cursor.to_view(Cursor.mapping("**ab**"),
    Cursor.to_source(Cursor.mapping("**ab**"), 1n)) == 1n : Nat}

# LAW: Empty documents have one valid cursor position.
law cursor_map_empty_document:
  {Cursor.mapping("") == [0n] : List<&2, Nat>}

# LAW: A non-BMP scalar occupies two native UTF-16 units.
law native_position_emoji:
  {Position.to_native("a😀b", 2n) == 3n : Nat}

# LAW: A native position inside a surrogate pair cannot split the scalar.
law native_position_surrogate_boundary:
  {Position.to_scalar("a😀b", 2n) == 2n : Nat}

# LAW: Replacing a source range preserves the text outside that range.
law source_range_replace:
  {Position.replace("a😀中文b", 1n, 4n, "日\n") == "a日\nb" : String}

# LAW: Selection direction does not change the replacement result.
law source_range_reverse:
  {Position.replace("a😀中文b", 4n, 1n, "日\n") == "a日\nb" : String}

# LAW: An active inline run shows exact source; other runs remain formatted.
law active_inline_projection:
  {Projection.runs("**ab** and *cd*", 13n, 13n) == [
    E.StrongRun{"ab"}, E.PlainRun{" and "}, E.PlainRun{"*cd*"}
  ] : List<&2, E.RenderRun>}

# LAW: Undo restores both source and selection after a direct edit.
law direct_undo_selection:
  {State.current(State.undo(State.edit(
    State.select(State.start("**ab** and *cd*"), 12n, 12n), 9n, 10n, "X")))
    == State.Snapshot{13n, 13n,
      Document.parse("**ab** and *cd*")} : State.Snapshot}

# LAW: A source snapshot retains line endings, Unicode, and literal fence text.
law snapshot_source_preservation:
  {State.source(State.current(State.start("# 中文\r\n\r\n```rs\r\n**😀**\r\n```\r\n")))
    == "# 中文\r\n\r\n```rs\r\n**😀**\r\n```\r\n" : String}

# LAW: Undo of raw replacement restores the exact prior source bytes.
law raw_replace_undo_source:
  {State.source(State.current(State.undo(State.replace_source(
    State.start("**中文**\r\n"), "new\n")))) == "**中文**\r\n" : String}

# LAW: Block parsing keeps source line endings and fence contents unchanged.
law block_source_preservation:
  {Blocks.source(Blocks.parse("# 中文\r\n\r\n```\r\n**literal**\r\n```\r\n"))
    == "# 中文\r\n\r\n```\r\n**literal**\r\n```\r\n" : String}

# LAW: A shorter fence cannot close a wider opening fence.
law block_fence_width:
  {Blocks.parse("````\n```\nx\n````\n") == [
    Blocks.Piece{Blocks.Fence{'`', 4n, True{}}, "````\n```\nx\n````\n"}
  ] : List<&2, Blocks.Piece>}

# LAW: A local heading edit preserves the identifiers of all unchanged blocks.
law document_stable_blocks:
  {Document.view(Document.apply(Document.parse("# a\n\n# b\n\n# c\n"), 7n, 8n, "B")) ==
    Document.View{[
      Document.Block{0n, Blocks.Heading{1n}, "# a\n"},
      Document.Block{1n, Blocks.Blank{}, "\n"},
      Document.Block{5n, Blocks.Heading{1n}, "# B\n"},
      Document.Block{3n, Blocks.Blank{}, "\n"},
      Document.Block{4n, Blocks.Heading{1n}, "# c\n"}
    ], 6n, 5n} : Document.View}

# LAW: Fenced text does not interpret emphasis or inline-code marks.
law fenced_scene_is_literal:
  {Scene.text(Scene.build("```\n**x** *y* `z`\n```\n\ntail", 26n, 26n))
    == "**x** *y* `z`\n\ntail" : String}

# LAW: An inactive empty heading retains its newline.
law empty_heading_scene_newline:
  {Scene.text(Scene.build("#\n\ntail", 5n, 5n)) == "\n\ntail" : String}

# LAW: A cursor in an earlier block cannot expose marks in a later block.
law later_block_stays_inactive:
  {Scene.text(Scene.build("**a**\n\n**b**", 0n, 0n)) == "**a**\n\nb" : String}

# LAW: Failed UTF-8 loading retains the exact input bytes.
law document_open_invalid_keeps_bytes:
  for +bytes: List<&2, U32>
  {DocumentOpen.loaded(None{}, bytes) == DocumentOpen.InvalidUtf8{bytes} : DocumentOpen.Outcome}

law app_document_keeps_destination:
  for +destination: AppDocument.Destination
  for +session: StoredEditor.Session
  {AppDocument.with_session(destination, session) == AppDocument.Document{destination, session} : AppDocument.Document}

# LAW: A failed host read preserves the requested destination and its error.
law resolved_open_read_failure:
  for +requested: String
  for +code: U32
  for +message: String
  {ResolvedOpen.received(Fail{(code, message)}, requested) == ResolvedOpen.ReadFailed{requested, code, message} : ResolvedOpen.Outcome}

# LAW: An empty host identity cannot construct a resolved app document.
law resolved_open_empty_identity:
  for +requested: String
  for +path: List<&2, U32>
  for +bytes: List<&2, U32>
  {ResolvedOpen.decode(ResolvedOpen.Raw{requested, path, Nil{}, bytes}) == ResolvedOpen.Rejected{ResolvedOpen.Raw{requested, path, Nil{}, bytes}, ResolvedOpen.InvalidIdentity{}} : ResolvedOpen.Outcome}

# LAW: Initial loading retains the exact disk observation.
law initial_open_keeps_observation:
  for +document: AppDocument.Document
  for +disk: List<&2, U32>
  {InitialOpen.decoded(ResolvedOpen.Opened{document}, disk) == InitialOpen.Opened{InitialOpen.Initial{document, disk}} : InitialOpen.Outcome}

# LAW: An untitled document cannot select a recovery record.
law app_recovery_untitled:
  for +session: StoredEditor.Session
  for +disk: List<&2, U32>
  for catalog: Scan.Outcome
  {AppRecovery.prepare(InitialOpen.Initial{AppDocument.Document{AppDocument.Untitled{}, session}, disk}, catalog) == AppRecovery.Unresolved{InitialOpen.Initial{AppDocument.Document{AppDocument.Untitled{}, session}, disk}} : AppRecovery.Outcome}

# LAW: Recovery changes the session without changing its destination.
law app_recovery_keeps_destination:
  for +destination: AppDocument.Destination
  for previous: StoredEditor.Session
  for +session: StoredEditor.Session
  for +disk: List<&2, U32>
  for requested: List<&2, U32>
  for +catalog: Scan.Catalog
  {AppRecovery.applied(StoredRecovery.Opened{requested, catalog, session}, InitialOpen.Initial{AppDocument.Document{destination, previous}, disk}) == AppRecovery.Opened{AppDocument.Document{destination, session}, disk, catalog} : AppRecovery.Outcome}

# LAW: Blocked recovery retains the complete initial observation and plan.
law app_recovery_keeps_blocked:
  for +initial: InitialOpen.Initial
  for +plan: Plan.Plan
  {AppRecovery.applied(StoredRecovery.Blocked{plan}, initial) == AppRecovery.Blocked{initial, plan} : AppRecovery.Outcome}

# LAW: Only absent settings select the disabled recovery branch.
law recovery_settings_absent:
  for supported: Bool
  {RecoverySettings.decode(Done{(supported, (None{}, None{}))}) == RecoverySettings.Disabled{} : RecoverySettings.Choice}

# LAW: Partial settings cannot disable recovery.
law recovery_settings_partial:
  for host: List<&2, U32>
  for supported: Bool
  {RecoverySettings.decode(Done{(supported, (Some{host}, None{}))}) == RecoverySettings.Invalid{"Set both the recovery host and catalog root"} : RecoverySettings.Choice}

# LAW: A plain Return edit keeps the requested source range.
law return_plain_edit:
  for body: String
  for offset: Nat
  for +start: Nat
  for end: Nat
  for newline: String
  {ListReturn.choose(False{}, body, offset, start, end, newline) == ListReturn.Edit{start, end, newline} : ListReturn.Edit}

# LAW: Exiting an empty item removes only its prefix.
law return_empty_item:
  for prefix: String
  for offset: Nat
  for +position: Nat
  for newline: String
  {ListReturn.item_kind(True{}, prefix, offset, position, newline) == ListReturn.Edit{offset, position, ""} : ListReturn.Edit}

# LAW: Composing presentation patches keeps the final document and selection.
law return_patch_snapshot:
  for +editor: State.Session
  for prior: List<&2, Scene.HostPatch>
  {State.current(ReturnCommand.with_prior(editor, prior)) == State.current(editor) : State.Snapshot}

# LAW: A rejected command retains the complete session during patch composition.
law return_patch_rejected:
  for +session: StoredEditor.Session
  for prior: List<&2, Scene.HostPatch>
  {ReturnCommand.composed(StoredEditor.Rejected{session}, prior) == StoredEditor.Rejected{session} : StoredEditor.EditResult}

# LAW: Removing a line boundary reparses the joined heading line.
law incremental_joined_line:
  {Document.view(Document.apply(Document.parse("#\n# h\n\ntail"), 1n, 2n, "")) == Document.View{[
    Document.Block{4n, Blocks.Heading{2n}, "## h\n"},
    Document.Block{2n, Blocks.Blank{}, "\n"},
    Document.Block{3n, Blocks.Paragraph{}, "tail"}
  ], 5n, 5n} : Document.View}
