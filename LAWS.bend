import Base
import ./Experiment.bend as E

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
