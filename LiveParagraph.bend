import Base
import ./Experiment.bend as E

type ParagraphEvent is Data:
  ParagraphChanged{text: String}
  ParagraphUndo{}
  ParagraphRedo{}
  ParagraphClosed{}

# Uses `Window` as the affine native handle because Bend 2 cannot define a new
# opaque handle type. Only this module may use the handle.
def LiveParagraph.open(initial: String) -> IO(Window):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

def LiveParagraph.next(window: Window) -> IO(Window & ParagraphEvent):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

def LiveParagraph.set(window: Window, text: String) -> IO(Window):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

def LiveParagraph.close(window: Window) -> IO(Unit):
  import "./live_paragraph.c"
  import "./live_paragraph.js"

def LiveParagraph.finish(
  update: Window & ParagraphEvent,
  history: E.History,
  rest: Window -> E.History -> IO(Unit)
) -> IO(Unit):
  (window, event) = update
  match event:
    case ParagraphClosed{}:
      LiveParagraph.close(window)
    case ParagraphChanged{next_text}:
      +committed = E.Paragraph.commit(next_text)
      +next_history = E.History.apply(committed, history)
      do IO<Unit>:
        IO.print(E.History.current(next_history))
        rest(window, next_history)
    case ParagraphUndo{}:
      +next_history = E.History.undo(history)
      do IO<Unit>:
        next_window : Window <- LiveParagraph.set(
          window, E.History.current(next_history)
        )
        rest(next_window, next_history)
    case ParagraphRedo{}:
      +next_history = E.History.redo(history)
      do IO<Unit>:
        next_window : Window <- LiveParagraph.set(
          window, E.History.current(next_history)
        )
        rest(next_window, next_history)

# The finite fuel keeps the proof boundary sound. A later host wake starts a new
# session if this large safety bound is ever reached.
def LiveParagraph.run(fuel: Nat, window: Window, history: E.History) -> IO(Unit):
  match fuel:
    case 0n:
      LiveParagraph.close(window)
    case 1n+rest:
      do IO<Unit>:
        update : (Window & ParagraphEvent) <- LiveParagraph.next(window)
        LiveParagraph.finish(
          update,
          history,
          next_window => next_history =>
            LiveParagraph.run(rest, next_window, next_history)
        )

def main() -> IO(Unit):
  do IO<Unit>:
    +initial : String = "Edit this paragraph. 中文输入 and 日本語入力 are welcome."
    window : Window <- LiveParagraph.open(initial)
    LiveParagraph.run(100000n, window, E.History.start(initial))
