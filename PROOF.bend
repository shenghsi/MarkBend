import Base
import ./LAWS.bend as Laws

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
