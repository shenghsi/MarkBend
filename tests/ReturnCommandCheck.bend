import Base
import ../src/ReturnCommand.bend as Return
import ../src/StoredEditor.bend as Stored
import ../src/DirectState.bend as Editor
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ../src/ScalarText.bend as Scalar
import ./RecoveryEditorCheck.bend as Encode
import ./StoredEditorCheck.bend as Storage
import ./SessionViewCheck.bend as View
import ./DirectCheck.bend as Check

def verified(+session: Stored.Session, +source: String, start: Nat, end: Nat,
  saved: Flat.State) -> Bool:
  match session:
    case Stored.Session{+editor, storage}:
      Storage.matches(session, source, saved) &&
        Check.snapshot_is(Editor.current(editor), source, start, end) && View.valid(editor)

def fixture(+source: String, native_start: Nat, native_end: Nat, source_start: Nat,
  source_end: Nat, +expected: String, +caret: Nat) -> IO(Unit):
  +initial = Flat.open(Encode.bytes(Utf8.encode(source)))
  +saved = Flat.edit(initial, Encode.bytes(Utf8.encode(expected)))
  do IO<Unit>:
    original : Stored.Session <- Storage.loaded(Stored.load(initial))
    +result : Stored.Session <- Storage.accepted(Return.command(original, native_start, native_end))
    Check.check(verified(result, expected, caret, caret, saved))
    Check.check(verified(Stored.undo(result), source, source_start, source_end, initial))
    Check.check(verified(Stored.redo(Stored.undo(result)), expected, caret, caret, saved))

def repeated(fuel: Nat, acc: String) -> String:
  match fuel:
    case 0n:
      acc
    case 1n+rest:
      repeated(rest, SCon{'x', acc})

def large() -> IO(Unit):
  +body = repeated(U32.to_nat(65536), "")
  +source = "- " ++ body
  +expected = "- " ++ Scalar.from_reversed(List.reverse(&2, Char, Scalar.to_chars(body)), "\n- ")
  fixture(source, U32.to_nat(65538), U32.to_nat(65538), U32.to_nat(65538), U32.to_nat(65538),
    expected, U32.to_nat(65541))

def main() -> IO(Unit):
  do IO<Unit>:
    fixture("- x", 3n, 3n, 3n, 3n, "- x\n- ", 6n)
    fixture("* 中😀", 5n, 5n, 4n, 4n, "* 中😀\n* ", 7n)
    fixture("+ ", 2n, 2n, 2n, 2n, "", 0n)
    fixture("- x", 2n, 3n, 2n, 3n, "- \n", 3n)
    fixture("- x\r\n- y", 8n, 8n, 8n, 8n, "- x\r\n- y\r\n- ", 12n)
    fixture("- x\r\n- y\n", 8n, 8n, 8n, 8n, "- x\r\n- y\n- \n", 11n)
    fixture("```\n```\n- x", 11n, 11n, 11n, 11n, "```\n```\n- x\n- ", 14n)
    IO.print("Return command short cases passed")
    large()
    IO.print("Return command exact source, selection, views, history, and long line passed")
