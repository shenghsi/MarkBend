import Base

# The cursor buffer stores the left side in reverse order. This makes an insert
# or a backspace at the cursor a constant-size rewrite.
type Buffer is Data:
  Buffer{left: List<&2, U32>, right: List<&2, U32>}

# Inserts one UTF-8 byte before the cursor.
def Buffer.insert(+byte: U32, buffer: Buffer) -> Buffer:
  match buffer:
    case Buffer{left, right}:
      Buffer{byte <> left, right}

# Removes one UTF-8 byte before the cursor.
def Buffer.backspace(buffer: Buffer) -> Maybe<&2, Buffer>:
  match buffer:
    case Buffer{Nil{}, right}:
      None{}
    case Buffer{byte <> left, right}:
      Some{Buffer{left, right}}

# Moves the cursor one byte to the left.
def Buffer.move_left(buffer: Buffer) -> Buffer:
  match buffer:
    case Buffer{Nil{}, right}:
      Buffer{Nil{}, right}
    case Buffer{byte <> left, right}:
      Buffer{left, byte <> right}

# Moves the cursor one byte to the right.
def Buffer.move_right(buffer: Buffer) -> Buffer:
  match buffer:
    case Buffer{left, Nil{}}:
      Buffer{left, Nil{}}
    case Buffer{left, byte <> right}:
      Buffer{byte <> left, right}

# Reconstructs the exact source order from the cursor zipper.
def Buffer.source(buffer: Buffer) -> List<&2, U32>:
  match buffer:
    case Buffer{left, right}:
      List.append(&2, U32, List.reverse(&2, U32, left), right)

# Counts bytes on both sides. The calls have independent, similar work when the
# cursor is near the middle. Bend can schedule these calls in parallel.
def Buffer.measure(buffer: Buffer) -> Nat & Nat:
  match buffer:
    case Buffer{left, right}:
      left_count right_count = List.length(&2, U32, left) List.length(&2, U32, right)
      (left_count, right_count)

# A first direct-formatting model. Strong marks stay in the source. The inactive
# projection hides only the marks.
type Strong is Data:
  Strong{text: List<&2, U32>}

def Strong.source(strong: Strong) -> List<&2, U32>:
  match strong:
    case Strong{text}:
      42 <> 42 <> List.append(&2, U32, text, [42, 42])

def Strong.view(active: Bool, strong: Strong) -> List<&2, U32>:
  match active strong:
    case True{} Strong{text}:
      42 <> 42 <> List.append(&2, U32, text, [42, 42])
    case False{} Strong{text}:
      text

# Source points name Markdown marks separately from text positions. This avoids
# an unstable raw view offset when inactive marks disappear.
type StrongPoint is Data:
  Opening{second: Bool}
  Content{offset: Nat}
  Closing{second: Bool}

# A projection either keeps an expanded source point or maps it to visible text.
type ProjectedPoint is Data:
  Expanded{point: StrongPoint}
  Text{offset: Nat}

def Strong.project(
  active: Bool, +content_length: Nat, point: StrongPoint
) -> ProjectedPoint:
  match active point:
    case True{} point:
      Expanded{point}
    case False{} Opening{second}:
      Text{0n}
    case False{} Content{offset}:
      Text{offset}
    case False{} Closing{second}:
      Text{content_length}

# The host may compose text, but Bend accepts the committed paragraph without
# normalization. Later experiments replace `String` with the byte buffer.
def Paragraph.commit(text: String) -> String:
  text

# Bend owns paragraph history. A new commit stores the prior text and clears the
# redo path. Lists are reusable because their strings are data.
type History is Data:
  History{
    present: String,
    undo: List<&2, String>,
    redo: List<&2, String>
  }

def History.start(text: String) -> History:
  History{text, Nil{}, Nil{}}

def History.current(history: History) -> String:
  match history:
    case History{present, undo, redo}:
      present

def History.apply(text: String, history: History) -> History:
  match history:
    case History{present, undo, redo}:
      History{text, present <> undo, Nil{}}

def History.undo(history: History) -> History:
  match history:
    case History{present, Nil{}, redo}:
      History{present, Nil{}, redo}
    case History{present, prior <> undo, redo}:
      History{prior, undo, present <> redo}

def History.redo(history: History) -> History:
  match history:
    case History{present, undo, Nil{}}:
      History{present, undo, Nil{}}
    case History{present, undo, next <> redo}:
      History{next, present <> undo, redo}

def History.redo_count(history: History) -> Nat:
  match history:
    case History{present, undo, redo}:
      List.length(&2, String, redo)

# The scan stores output and strong content in reverse order. A closing pair
# folds the content into output. End-of-input restores an unfinished opening.
type MarkdownMode is Data:
  MarkdownText{reversed: List<&2, Char>}
  MarkdownStrong{
    output_reversed: List<&2, Char>,
    strong_reversed: List<&2, Char>
  }

def Markdown.scan(
  chars: List<&2, Char>, mode: MarkdownMode
) -> List<&2, Char>:
  match chars mode:
    case '*' <> '*' <> rest MarkdownText{output}:
      Markdown.scan(rest, MarkdownStrong{output, Nil{}})
    case char <> rest MarkdownText{output}:
      Markdown.scan(rest, MarkdownText{char <> output})
    case Nil{} MarkdownText{output}:
      List.reverse(&2, Char, output)
    case '*' <> '*' <> rest MarkdownStrong{output, strong}:
      Markdown.scan(rest, MarkdownText{
        List.append(&2, Char, strong, output)
      })
    case char <> rest MarkdownStrong{output, strong}:
      Markdown.scan(rest, MarkdownStrong{output, char <> strong})
    case Nil{} MarkdownStrong{output, strong}:
      List.reverse(&2, Char,
        List.append(&2, Char, strong, '*' <> '*' <> output))

# Hides only paired strong marks. An unfinished opening pair remains visible.
def Markdown.hide_strong_marks(chars: List<&2, Char>) -> List<&2, Char>:
  Markdown.scan(chars, MarkdownText{Nil{}})

type Projection is Data:
  Projection{source: String, view: String}

def Markdown.project(active: Bool, +source: String) -> Projection:
  match active:
    case True{}:
      Projection{source, source}
    case False{}:
      Projection{
        source,
        String.from_list(Markdown.hide_strong_marks(String.to_list(source)))
      }

def Projection.source(projection: Projection) -> String:
  match projection:
    case Projection{source, view}:
      source

def Projection.view(projection: Projection) -> String:
  match projection:
    case Projection{source, view}:
      view

# Recognizes a paragraph that is exactly one strong span.
def Markdown.whole_strong_content(
  chars: List<&2, Char>, reversed: List<&2, Char>
) -> Maybe<&2, String>:
  match chars:
    case '*' <> '*' <> Nil{}:
      Some{String.from_list(List.reverse(&2, Char, reversed))}
    case char <> rest:
      Markdown.whole_strong_content(rest, char <> reversed)
    case Nil{}:
      None{}

def Markdown.whole_strong_chars(chars: List<&2, Char>) -> Maybe<&2, String>:
  match chars:
    case '*' <> '*' <> rest:
      Markdown.whole_strong_content(rest, Nil{})
    case other:
      None{}

def Markdown.whole_strong(source: String) -> Maybe<&2, String>:
  Markdown.whole_strong_chars(String.to_list(source))

type FirstStrongMode is Data:
  FirstStrongText{before_reversed: List<&2, Char>}
  FirstStrongBody{
    before_reversed: List<&2, Char>,
    strong_reversed: List<&2, Char>
  }

type FirstStrongRender is Data:
  RenderPlain{text: String}
  RenderFirstStrong{before: String, strong: String, after: String}

def Markdown.first_strong_scan(
  chars: List<&2, Char>, mode: FirstStrongMode
) -> FirstStrongRender:
  match chars mode:
    case '*' <> '*' <> rest FirstStrongText{before}:
      Markdown.first_strong_scan(rest, FirstStrongBody{before, Nil{}})
    case char <> rest FirstStrongText{before}:
      Markdown.first_strong_scan(rest, FirstStrongText{char <> before})
    case Nil{} FirstStrongText{before}:
      RenderPlain{String.from_list(List.reverse(&2, Char, before))}
    case '*' <> '*' <> rest FirstStrongBody{before, strong}:
      RenderFirstStrong{
        String.from_list(List.reverse(&2, Char, before)),
        String.from_list(List.reverse(&2, Char, strong)),
        String.from_list(rest)
      }
    case char <> rest FirstStrongBody{before, strong}:
      Markdown.first_strong_scan(rest, FirstStrongBody{before, char <> strong})
    case Nil{} FirstStrongBody{before, strong}:
      RenderPlain{String.from_list(List.reverse(&2, Char,
        List.append(&2, Char, strong, '*' <> '*' <> before)))}

def Markdown.first_strong(source: String) -> FirstStrongRender:
  Markdown.first_strong_scan(
    String.to_list(source), FirstStrongText{Nil{}}
  )

type RenderRun is Data:
  PlainRun{text: String}
  StrongRun{text: String}

type RenderMode is Data:
  RenderText{
    plain_reversed: List<&2, Char>,
    runs_reversed: List<&2, RenderRun>
  }
  RenderStrong{
    plain_reversed: List<&2, Char>,
    strong_reversed: List<&2, Char>,
    runs_reversed: List<&2, RenderRun>
  }

def Markdown.push_plain(
  reversed: List<&2, Char>, runs: List<&2, RenderRun>
) -> List<&2, RenderRun>:
  match reversed:
    case Nil{}:
      runs
    case char <> rest:
      PlainRun{String.from_list(List.reverse(&2, Char, char <> rest))} <> runs

def Markdown.render_scan(
  chars: List<&2, Char>, mode: RenderMode
) -> List<&2, RenderRun>:
  match chars mode:
    case '*' <> '*' <> rest RenderText{plain, runs}:
      Markdown.render_scan(rest, RenderStrong{plain, Nil{}, runs})
    case char <> rest RenderText{plain, runs}:
      Markdown.render_scan(rest, RenderText{char <> plain, runs})
    case Nil{} RenderText{plain, runs}:
      List.reverse(&2, RenderRun, Markdown.push_plain(plain, runs))
    case '*' <> '*' <> rest RenderStrong{plain, strong, runs}:
      next_runs : List<&2, RenderRun> = StrongRun{
        String.from_list(List.reverse(&2, Char, strong))
      } <> Markdown.push_plain(plain, runs)
      Markdown.render_scan(rest, RenderText{Nil{}, next_runs})
    case char <> rest RenderStrong{plain, strong, runs}:
      Markdown.render_scan(rest, RenderStrong{plain, char <> strong, runs})
    case Nil{} RenderStrong{plain, strong, runs}:
      restored = List.append(&2, Char, strong, '*' <> '*' <> plain)
      List.reverse(&2, RenderRun, Markdown.push_plain(restored, runs))

def Markdown.render_runs(source: String) -> List<&2, RenderRun>:
  Markdown.render_scan(
    String.to_list(source), RenderText{Nil{}, Nil{}}
  )

# Runs a small model experiment. The result is `(left bytes, right bytes)` after
# one insert and one cursor move.
def main() -> Nat & Nat:
  start : Buffer = Buffer{
    {[65, 66] : List<&2, U32>},
    {[67, 68] : List<&2, U32>}
  }
  changed = Buffer.insert(88, start)
  Buffer.measure(Buffer.move_right(changed))
