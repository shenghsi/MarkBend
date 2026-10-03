import Base
import ../src/DocumentOpen.bend as Open
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./StoredEditorCheck.bend as Editor
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def source() -> String:
  "\u{feff}# 中文😀\r\n\0"

def checked(mode: U32, value: Open.Outcome) -> IO(Unit):
  match mode value:
    case 0 Open.Opened{session}:
      Check.check(Editor.matches(session, source(), Save.open(Encode.bytes(Utf8.encode(source())))))
    case 1 Open.InvalidUtf8{bytes}:
      Check.check(Save.bytes_equal(bytes, [255,0,195,40]))
    case 2 Open.Opened{session}:
      Check.check(Editor.matches(session, "", Save.open(Nil{})))
    case 3 Open.ReadFailed{code, message}:
      IO.pure(Unit, Unit{})
    case _ _:
      Check.check(False{})

def written(value: File & Result<&1, &1, U32 & String, Unit>, path: String,
  mode: U32) -> IO(Unit):
  match value:
    case (file, result):
      do IO<Unit>:
        File.close(file)
        IO.pass(Unit, result)
        opened : Open.Outcome <- Open.read(path)
        checked(mode, opened)

def fixture(+path: String, bytes: List<&2, U32>, mode: U32) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(file, bytes)
    written(result, path, mode)

def main() -> IO(Unit):
  do IO<Unit>:
    +path : String <- IO.try(String, IO.get_env("MARKBEND_OPEN_CHECK_PATH"))
    Check.check(Open.fits(3n, [1,2,3]))
    Check.check(Bool.not(Open.fits(3n, [1,2,3,4])))
    fixture(path, Encode.bytes(Utf8.encode(source())), 0)
    fixture(path, [255,0,195,40], 1)
    fixture(path, Nil{}, 2)
    missing : Open.Outcome <- Open.read(path ++ ".missing")
    checked(3, missing)
    IO.print("File opening exact bytes, invalid UTF-8, empty file, and read failure check passed")
