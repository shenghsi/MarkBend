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
