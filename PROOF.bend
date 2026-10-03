import Base
import ./LAWS.bend as Laws
import ./src/BlockIndex.bend as Index
import ./src/SaveState.bend as Save
import ./src/AppSaveAs.bend as SaveAs
import ./src/AppDocument.bend as App
import ./src/DirectState.bend as State
import ./src/ProjectionWidthProof.bend as WidthProof

def Laws.projection_width_matches_consume(visible, chars, offset, plain):
  WidthProof.consume(visible, chars, offset, plain)

def Laws.projection_part_matches_reference(run, chars):
  WidthProof.part(run, chars)

def Laws.new_file_observation_retains_workspace(workspace, id):
  match workspace:
    case SaveAs.Editing{document}:
      {==}
    case SaveAs.Saving{document, target, active, snapshot}:
      {==}
    case SaveAs.Uncertain{document, target, active, snapshot}:
      {==}

def Laws.workspace_uncertain_blocks_save(document, target, id, snapshot):
  {==}

def Laws.workspace_uncertain_blocks_close(document, target, id, snapshot):
  {==}

def Laws.workspace_uncertain_input_retains(document, target, id, snapshot):
  {==}

def Laws.app_save_as_cancel_keeps_workspace(value):
  match value:
    case SaveAs.Editing{App.Document{destination, session}}:
      {==}
    case SaveAs.Saving{document, target, id, snapshot}:
      {==}
    case SaveAs.Uncertain{document, target, id, snapshot}:
      {==}

def Laws.app_save_as_uncertain_completion_keeps_transaction(document, target, id, snapshot, response, outcome):
  {==}

def Laws.app_input_unavailable_retains_document(document):
  {==}

def Laws.app_input_keep_open_suspends_document(document):
  {==}

def Laws.app_save_cancel_keeps_document(document):
  {==}

def Laws.app_save_failed_close_keeps_document(document):
  {==}

def Laws.app_save_uncertain_close_keeps_document(document):
  {==}

def Laws.app_save_untitled_has_no_request(session):
  {==}

def Laws.editor_release_both_finished():
  {==}

def Laws.scene_release_zero_keeps_queue(item, rest):
  {==}

def Laws.text_release_zero_keeps_queue(item, rest):
  {==}

def Laws.byte_release_zero_keeps_queue(tree, rest):
  {==}

def Laws.storage_history_clear_preserves_current(current, undo, redo, save, identity):
  {==}

def Laws.storage_history_known_snapshot_is_clean(save):
  {==}

def Laws.byte_comparison_unequal_lengths(left, right):
  {==}

def Laws.stored_recovery_failed_load_keeps_plan(plan, requested, catalog):
  {==}

def Laws.stored_editor_failed_replacement_keeps_session(history, session, text):
  {==}

def Laws.stored_editor_failed_edit_keeps_session(history, session, start, end, text):
  {==}

def Laws.storage_history_failed_edit_keeps_session(snapshot, session):
  {==}

def Laws.persistent_save_uncertain_keeps_state(state, id):
  {==}

def Laws.persistent_save_unsynced_keeps_state(state, id, observed):
  {==}

def Laws.recovery_scan_keeps_read_error(code, text, name):
  {==}

def Laws.byte_buffer_invalid_input_is_rejected(bytes):
  {==}

def Laws.text_byte_mapping_rejects_invalid_text(text):
  {==}

def Laws.text_byte_invalid_replacement_is_rejected(map, first, removed):
  {==}

def Laws.text_storage_failed_mapping_keeps_snapshot(original, insert, start, end):
  {==}

def Laws.utf8_incomplete_is_rejected(code, minimum, reversed):
  {==}

def Laws.recovery_editor_invalid_text_keeps_plan(plan, requested, catalog, save):
  {==}

def Laws.recovery_editor_invalid_edit_keeps_models(previous, requested, catalog, save, attempted):
  {==}

def Laws.recovery_plan_incomplete_requires_review(catalog, selection, requested, disk):
  {==}

def Laws.recovery_scan_keeps_invalid_origin(name):
  {==}

def Laws.recovery_lookup_retains_duplicates(first, second, rest):
  {==}

def Laws.invalid_lookup_keeps_candidates(entries, requested):
  {==}

def Laws.recovery_entry_mismatch_keeps_versions(entry, disk):
  {==}

def Laws.recovery_conflict_keeps_versions(recorded, disk):
  {==}

def Laws.recovery_keeps_current_bytes(current, saved, next, pending, disk):
  {==}

def Laws.unrecognized_save_keeps_state(state, id):
  {==}

def Laws.unsynced_save_keeps_state(state, id, observed):
  match state:
    case Save.State{current, saved, next, None{}}:
      {==}
    case Save.State{current, saved, next, Some{Save.Ticket{ticket_id, bytes}}}:
      {==}

def Laws.uncertain_save_keeps_state(state, id):
  {==}

def Laws.save_request_keeps_pending(current, saved, next, ticket):
  {==}

def Laws.save_failure_keeps_baseline(current, saved, next, bytes):
  {==}

def Laws.save_success_keeps_current(current, saved, next, bytes):
  {==}

def Laws.stale_save_keeps_pending(ok, current, saved, next, ticket):
  {==}

def Laws.host_chunks_active_heading():
  {==}

def Laws.changed_block_interval():
  {==}

def Laws.host_chunks_active_strong():
  {==}

def Laws.cached_points_shift(runs, x, y, offset):
  {==}

def Laws.cached_repeat_scene():
  {==}

def Laws.indexed_surrogate_boundary():
  {==}

def Laws.indexed_hidden_source_boundary():
  {==}

def Laws.snapshot_source_preservation():
  {==}

def Laws.raw_replace_undo_source():
  {==}

# Each first-experiment law follows by reducing the named operations.
def Laws.insert_then_backspace(byte, left, right):
  {==}

def Laws.left_then_right(byte, left, right):
  {==}

def Laws.active_strong_is_source(text):
  {==}

def Laws.inactive_strong_is_content(text):
  {==}

def Laws.empty_left_source(right):
  {==}

def Laws.active_point_is_expanded(content_length, point):
  {==}

def Laws.inactive_opening_is_start(content_length, second):
  {==}

def Laws.inactive_closing_is_end(content_length, second):
  {==}

def Laws.inactive_content_keeps_offset(content_length, offset):
  {==}

def Laws.paragraph_commit_preserves_text(text):
  {==}

def Laws.undo_after_apply_restores_text(present, next, undo, redo):
  {==}

def Laws.redo_after_undo_restores_text(present, next, undo, redo):
  {==}

def Laws.apply_clears_redo(present, next, undo, redo):
  {==}

def Laws.undo_without_prior_is_stable(present, redo):
  {==}

def Laws.projection_preserves_source(active, source):
  match active:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.active_projection_shows_source(source):
  {==}

def Laws.inactive_projection_hides_strong_marks():
  {==}

def Laws.inactive_projection_keeps_unclosed_marks():
  {==}

def Laws.inactive_projection_hides_multiple_spans():
  {==}

def Laws.inactive_projection_keeps_single_star():
  {==}

def Laws.whole_strong_finds_content():
  {==}

def Laws.whole_strong_rejects_unclosed():
  {==}

def Laws.first_strong_splits_mixed_text():
  {==}

def Laws.first_strong_keeps_unclosed_text():
  {==}

def Laws.render_runs_support_multiple_strong_spans():
  {==}

def Laws.render_runs_restore_unclosed_span():
  {==}

def Laws.render_runs_mix_emphasis_and_strong():
  {==}

def Laws.render_runs_restore_unclosed_emphasis():
  {==}

def Laws.render_runs_keep_later_unclosed_emphasis():
  {==}

def Laws.render_runs_keep_code_literal():
  {==}

def Laws.render_runs_restore_unclosed_code():
  {==}

def Laws.render_runs_keep_escaped_marks():
  {==}

def Laws.cursor_map_mixed_runs():
  {==}

def Laws.cursor_map_unicode_and_escape():
  {==}

def Laws.cursor_map_unfinished_span():
  {==}

def Laws.cursor_map_hidden_opening():
  {==}

def Laws.cursor_map_hidden_closing():
  {==}

def Laws.cursor_map_clamps_view():
  {==}

def Laws.cursor_map_content_roundtrip():
  {==}

def Laws.cursor_map_empty_document():
  {==}

def Laws.native_position_emoji():
  {==}

def Laws.native_position_surrogate_boundary():
  {==}

def Laws.source_range_replace():
  {==}

def Laws.source_range_reverse():
  {==}

def Laws.active_inline_projection():
  {==}

def Laws.direct_undo_selection():
  {==}

def Laws.block_source_preservation():
  {==}

def Laws.block_fence_width():
  {==}

def Laws.document_stable_blocks():
  {==}

def Laws.fenced_scene_is_literal():
  {==}

def Laws.empty_heading_scene_newline():
  {==}

def Laws.later_block_stays_inactive():
  {==}

def Laws.incremental_joined_line():
  {==}

def Laws.index_empty_prefix(tree):
  match tree:
    case Index.Empty{}:
      {==}
    case Index.Leaf{value, width}:
      {==}
    case Index.Branch{left, right, size, count, height}:
      {==}

def Laws.index_pair_length(a, b, x, y):
  {==}

def Laws.empty_undo_keeps_view(snapshot, redo, view, cache, index):
  {==}

def Laws.empty_redo_keeps_view(snapshot, undo, view, cache, index):
  {==}

def Laws.edited_view_matches_source():
  {==}

def Laws.document_open_invalid_keeps_bytes(bytes):
  {==}

def Laws.app_document_keeps_destination(destination, session):
  {==}

def Laws.resolved_open_read_failure(requested, code, message):
  {==}

def Laws.resolved_open_empty_identity(requested, path, bytes):
  {==}

def Laws.initial_open_keeps_observation(document, disk):
  {==}

def Laws.app_recovery_untitled(session, disk, catalog):
  {==}

def Laws.app_recovery_keeps_destination(destination, previous, session, disk, requested, catalog):
  {==}

def Laws.app_recovery_keeps_blocked(initial, plan):
  {==}

def Laws.recovery_settings_absent(supported):
  {==}

def Laws.recovery_settings_partial(host, supported):
  {==}

def Laws.return_plain_edit(body, offset, start, end, newline):
  {==}

def Laws.return_empty_item(prefix, offset, position, newline):
  {==}

def Laws.return_patch_snapshot(editor, prior):
  match editor:
    case State.Session{current, undo, redo, State.RawView{scene, host, patches}, cache, index}:
      {==}

def Laws.return_patch_rejected(session, prior):
  {==}
