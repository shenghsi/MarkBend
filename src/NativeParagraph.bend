import Base
import ./Experiment.bend as E

# Opens one native paragraph field and returns its committed text.
def NativeParagraph.edit(initial: String) -> IO(String):
  import "./native_paragraph.c"
  import "./native_paragraph.js"

def main() -> IO(Unit):
  do IO<Unit>:
    text : String <- NativeParagraph.edit(
      "Edit this paragraph. 中文输入 and 日本語入力 are welcome."
    )
    IO.print(E.Paragraph.commit(text))
