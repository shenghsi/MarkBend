import Base
import ../src/StorageHistory.bend as History
import ../src/DirectState.bend as Editor
import ../src/Document.bend as Document
import ../src/Blocks.bend as Blocks
import ../src/BlockIndex.bend as Index
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./DocumentBench.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def loaded(value: Maybe<&2, History.Session>) -> Bool:
  match value:
    case Some{session}:
      True{}
    case None{}:
      False{}

def run(+size: Nat) -> IO(Unit):
  +source = Fixture.sample(size)
  do IO<Unit>:
    IO.print("Large fixture prepared")
    Check.check(loaded(History.load(Save.open(Encode.bytes(Utf8.encode(source))))))
    IO.print("Large storage loaded")
    Check.check(Nat.is_gt(Index.list_count(Blocks.Piece, Blocks.parse(source), 0n), 0n))
    IO.print("Large block parsing completed")
    +parsed : Document.Document = Document.parse(source)
    Check.check(Nat.is_eq(Editor.document_length(parsed), size))
    IO.print("Large document parsed")
    Check.check(Nat.is_eq(Document.count_scalars(Editor.document_source(parsed), 0n), size))
    IO.print("Large source reconstruction completed")
    session : Editor.Session = Editor.start(source)
    IO.print("Large formatted editor loaded")
    Check.check(Nat.is_eq(Editor.source_length(Editor.current(session)), size))
    IO.print("Large editor load probe passed")

def main() -> IO(Unit):
  run(102400n)
