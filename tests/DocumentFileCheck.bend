import Base
import ../src/DocumentFile.bend as File
import ../src/Utf8.bend as Utf8
import ./Utf8Check.bend as Text
import ./FileBytesCheck.bend as Fixture
import ./DirectCheck.bend as Check

def zeros(bytes: List<&2, U32>, +count: Nat, ok: Bool) -> Bool:
  match bytes ok:
    case _ False{}:
      False{}
    case Nil{} True{}:
      Nat.is_eq(count, 8388608n)
    case byte <> rest True{}:
      zeros(rest, 1n+count, U32.is_eq(byte, 0))

def body(mode: String, +bytes: List<&2, U32>) -> Bool:
  match mode:
    case "bytes":
      Text.encoded(Some{bytes}, Fixture.fixture()) && Text.rejected(Utf8.decode(bytes))
    case "empty":
      List.is_empty(&2, U32, bytes)
    case "limit":
      zeros(bytes, 0n, True{})
    case _:
      False{}

def checked(value: Result<&1, &1, U32 & String,
  List<&2, U32> & (List<&2, U32> & List<&2, U32>)>, +expected: String, mode: String) -> IO(Unit):
  match value:
    case Fail{(code, message)}:
      Check.check(String.eq(mode, "reject") && U32.is_gt(code, 0))
    case Done{(path, (identity, bytes))}:
      do IO<Unit>:
        Check.check(Text.decoded(Utf8.decode(path), expected))
        Check.check(Text.encoded(Utf8.encode("PATH1:" ++ expected), identity))
        Check.check(body(mode, bytes))

def run(requested: String, expected: String, mode: String) -> IO(Unit):
  do IO<Unit>:
    value : Result<&1, &1, U32 & String,
      List<&2, U32> & (List<&2, U32> & List<&2, U32>)> <- File.read_raw(requested)
    checked(value, expected, mode)

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> requested <> expected <> mode <> Nil{}:
      run(requested, expected, mode)
    case program <> path <> Nil{}:
      run(path ++ "\0ignored", "", "reject")
    case _:
      IO.die(Unit, 1, "Supply requested path, resolved path, and check mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
