import Base
import ../src/NewFilePublish.bend as Host
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def raw(+path: String, parent: String, mode: String) -> IO(U32):
  match mode:
    case "bad-identity":
      Host.publish_raw(path, [256], Encode.bytes(Utf8.encode(parent)), [65])
    case "bad-parent":
      Host.publish_raw(path, Encode.bytes(Utf8.encode("PATH1:" ++ path)), [256], [65])
    case "bad-output":
      Host.publish_raw(path, Encode.bytes(Utf8.encode("PATH1:" ++ path)), Encode.bytes(Utf8.encode(parent)), [256])
    case _:
      Host.publish_raw(path, Encode.bytes(Utf8.encode("PATH1:" ++ path)), Encode.bytes(Utf8.encode(parent)),
        [239, 187, 191, 228, 184, 173, 240, 159, 152, 128, 13, 10, 0])

def expected(mode: String) -> U32:
  match mode:
    case "save":
      0
    case "conflict":
      3
    case "unavailable":
      4
    case _:
      1

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> path <> parent <> +mode <> Nil{}:
      do IO<Unit>:
        code : U32 <- raw(path, parent, mode)
        Check.check(U32.is_eq(code, expected(mode)))
        IO.print("New-file publication host result passed")
    case _:
      IO.die(Unit, 1, "Supply path, parent identity, and expected mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
