import Base
import ../src/DocumentSave.bend as Host
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def checked(code: U32, mode: String) -> IO(Unit):
  match mode:
    case "save":
      Check.check(U32.is_eq(code, 0))
    case "conflict":
      Check.check(U32.is_eq(code, 3))
    case "unavailable":
      Check.check(U32.is_eq(code, 4))
    case _:
      Check.check(U32.is_eq(code, 1))

def raw(+path: String, mode: String) -> IO(U32):
  match mode:
    case "bad-identity":
      Host.write_raw(path, [256], [65, 13, 10, 0, 255], [66])
    case "bad-baseline":
      Host.write_raw(path, Encode.bytes(Utf8.encode("PATH1:" ++ path)), [256], [66])
    case "bad-output":
      Host.write_raw(path, Encode.bytes(Utf8.encode("PATH1:" ++ path)), [65, 13, 10, 0, 255], [256])
    case _:
      Host.write_raw(path, Encode.bytes(Utf8.encode("PATH1:" ++ path)),
        [65, 13, 10, 0, 255], [239, 187, 191, 228, 184, 173, 240, 159, 152, 128, 13, 10, 0])

def run(path: String, +mode: String) -> IO(Unit):
  do IO<Unit>:
    code : U32 <- raw(path, mode)
    checked(code, mode)

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> path <> mode <> Nil{}:
      run(path, mode)
    case _:
      IO.die(Unit, 1, "Supply save path and expected mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
