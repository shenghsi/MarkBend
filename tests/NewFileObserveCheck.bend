import Base
import ../src/NewFileObserve.bend as Host
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def expected(mode: String) -> U32:
  match mode:
    case "confirmed":
      0
    case _:
      1

def run(+path: String, parent: String, mode: String) -> IO(Unit):
  match mode:
    case "bad-identity":
      do IO<Unit>:
        code : U32 <- Host.observe_raw(path, [256], Encode.bytes(Utf8.encode(parent)), [65])
        Check.check(U32.is_eq(code, 1))
        IO.print("New-file observation effect passed")
    case "bad-parent":
      do IO<Unit>:
        code : U32 <- Host.observe_raw(path, Encode.bytes(Utf8.encode("PATH1:" ++ path)), [256], [65])
        Check.check(U32.is_eq(code, 1))
        IO.print("New-file observation effect passed")
    case "nul-path":
      do IO<Unit>:
        code : U32 <- Host.observe_raw(path ++ "\0suffix", Encode.bytes(Utf8.encode("PATH1:" ++ path)), Encode.bytes(Utf8.encode(parent)), [65])
        Check.check(U32.is_eq(code, 1))
        IO.print("New-file observation effect passed")
    case "bad-output":
      do IO<Unit>:
        code : U32 <- Host.observe_raw(path, Encode.bytes(Utf8.encode("PATH1:" ++ path)), Encode.bytes(Utf8.encode(parent)), [256])
        Check.check(U32.is_eq(code, 1))
        IO.print("New-file observation effect passed")
    case mode:
      do IO<Unit>:
        code : U32 <- Host.observe_raw(path, Encode.bytes(Utf8.encode("PATH1:" ++ path)), Encode.bytes(Utf8.encode(parent)),
          [239,187,191,228,184,173,240,159,152,128,13,10,0])
        Check.check(U32.is_eq(code, expected(mode)))
        IO.print("New-file observation effect passed")

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> path <> parent <> mode <> Nil{}:
      run(path, parent, mode)
    case _:
      IO.die(Unit, 1, "Supply observation path, parent key, and mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
