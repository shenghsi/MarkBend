import Base
import ../src/ResolvedFile.bend as Reader
import ../src/ResolvedOpen.bend as Open
import ../src/AppDocument.bend as App
import ../src/LiveParagraph.bend as Live
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./StoredEditorCheck.bend as Stored
import ./RecoveryEditorCheck.bend as Encode
import ./Utf8Check.bend as Text
import ./DirectCheck.bend as Check

type Step is Data:
  Step{event: Live.ParagraphEvent, source: String}

def Driver.invalid() -> IO(String):
  import "./invalid_string.c"
  import "./invalid_string.js"

def original() -> String:
  "ab 中文😀\r\n\0"

def steps(+invalid: String) -> List<&2, Step>:
  +edited : String = "X" ++ original()
  +replaced : String = "# 新😀\r\n\0"
  [Step{Live.ParagraphSelected{1, 3}, original()},
   Step{Live.ParagraphEdit{0, 0, "X"}, edited},
   Step{Live.ParagraphEdit{0, 0, invalid}, edited},
   Step{Live.ParagraphChanged{invalid}, edited},
   Step{Live.ParagraphUndo{}, original()},
   Step{Live.ParagraphRedo{}, edited},
   Step{Live.ParagraphChanged{replaced}, replaced},
   Step{Live.ParagraphUndo{}, edited},
   Step{Live.ParagraphRedo{}, replaced}]

def checked(+document: App.Document, +requested: String, +resolved: String,
  +source: String) -> IO(Unit):
  match document:
    case App.Document{App.Resolved{actual, path, identity}, session}:
      do IO<Unit>:
        Check.check(Text.text_equal(actual, requested, True{}))
        Check.check(Text.text_equal(path, resolved, True{}))
        Check.check(Text.encoded(Utf8.encode("PATH1:" ++ resolved), identity))
        Check.check(Stored.matches(session, source,
          Save.edit(Save.open(Encode.bytes(Utf8.encode(original()))),
            Encode.bytes(Utf8.encode(source)))))
    case _:
      IO.die(Unit, 1, "Resolved destination was lost in an editor callback")

def run(remaining: List<&2, Step>, window: Window, document: App.Document,
  +requested: String, +resolved: String) -> IO(Unit):
  match remaining:
    case Nil{}:
      do IO<Unit>:
        Live.LiveParagraph.close(window)
        IO.print("Resolved destination, source, and saved bytes survived all editor callbacks")
    case Step{event, source} <> rest:
      Live.LiveParagraph.finish_document((window, event), document,
        w => +d => do IO<Unit>:
          checked(d, requested, resolved, source)
          run(rest, w, d, requested, resolved))

def opened(value: Open.Outcome, +requested: String, +resolved: String) -> IO(Unit):
  match value:
    case Open.Opened{+document}:
      match document:
        case App.Document{destination, Editor.Session{editor, storage}}:
          do IO<Unit>:
            checked(document, requested, resolved, original())
            +invalid : String <- Driver.invalid()
            Check.check(Text.rejected_text(Utf8.encode(invalid)))
            window : Window <- Live.LiveParagraph.open(original())
            shown : Window <- Live.LiveParagraph.present(window, editor)
            run(steps(invalid), shown, document, requested, resolved)
    case _:
      IO.die(Unit, 1, "Resolved callback fixture did not open")

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> +requested <> +resolved <> Nil{}:
      do IO<Unit>:
        value : Open.Outcome <- Reader.read(requested)
        opened(value, requested, resolved)
    case _:
      IO.die(Unit, 1, "Supply requested and resolved fixture paths")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
