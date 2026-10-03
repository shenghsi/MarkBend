import Base
import ../src/ResolvedFile.bend as Reader
import ../src/ResolvedOpen.bend as Open
import ../src/AppDocument.bend as App
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./StoredEditorCheck.bend as Stored
import ./RecoveryEditorCheck.bend as Encode
import ./Utf8Check.bend as Text
import ./DirectCheck.bend as Check

def source(mode: String) -> String:
  match mode:
    case "empty":
      ""
    case _:
      "\u{feff}# 中文😀\r\n\0"

def checked(value: Open.Outcome, +requested: String, +expected: String, +mode: String) -> IO(Unit):
  match value:
    case Open.Opened{App.Document{App.Resolved{actual, path, identity}, session}}:
      do IO<Unit>:
        Check.check(Text.text_equal(actual, requested, True{}))
        Check.check(Text.text_equal(path, expected, True{}))
        Check.check(Text.encoded(Utf8.encode("PATH1:" ++ expected), identity))
        Check.check(Stored.matches(session, source(mode), Save.open(Encode.bytes(Utf8.encode(source(mode))))))
    case Open.Rejected{Open.Raw{actual, path, identity, bytes}, Open.InvalidUtf8{}}:
      do IO<Unit>:
        Check.check(String.eq(mode, "invalid"))
        Check.check(Text.text_equal(actual, requested, True{}))
        Check.check(Text.decoded(Utf8.decode(path), expected))
        Check.check(Text.encoded(Utf8.encode("PATH1:" ++ expected), identity))
        Check.check(Save.bytes_equal(bytes, [255]))
    case Open.Rejected{Open.Raw{actual, +path, identity, bytes}, Open.InvalidPath{}}:
      do IO<Unit>:
        Check.check(String.eq(mode, "invalid-path"))
        Check.check(Text.text_equal(actual, requested, True{}))
        Check.check(Save.bytes_equal(path, List.append(&2, U32, Encode.bytes(Utf8.encode(expected)), [255])))
        Check.check(Save.bytes_equal(identity, List.append(&2, U32, Encode.bytes(Utf8.encode("PATH1:")), path)))
        Check.check(Text.encoded(Utf8.encode(source("valid")), bytes))
    case Open.ReadFailed{actual, code, message}:
      do IO<Unit>:
        Check.check(String.eq(mode, "reject") && U32.is_gt(code, 0))
        Check.check(Text.text_equal(actual, requested, True{}))
    case _:
      IO.die(Unit, 1, "Resolved file outcome shape failed")

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> +requested <> expected <> mode <> Nil{}:
      do IO<Unit>:
        value : Open.Outcome <- Reader.read(requested)
        checked(value, requested, expected, mode)
    case _:
      IO.die(Unit, 1, "Supply requested path, resolved path, and mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
