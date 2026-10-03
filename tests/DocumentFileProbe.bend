import Base
import ../src/DocumentFile.bend as File
import ../src/BlockIndex.bend as Index

def report(value: Result<&1, &1, U32 & String,
  List<&2, U32> & (List<&2, U32> & List<&2, U32>)>) -> IO(Unit):
  match value:
    case Fail{(code, message)}:
      IO.print("failure:" ++ U32.show(code) ++ ":" ++ message)
    case Done{(path, (key, bytes))}:
      IO.print("opened:path_bytes=" ++ Nat.show(Index.list_count(U32, path, 0n)) ++
        " identity_bytes=" ++ Nat.show(Index.list_count(U32, key, 0n)) ++
        " document_bytes=" ++ Nat.show(Index.list_count(U32, bytes, 0n)))

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> path <> Nil{}:
      do IO<Unit>:
        value : Result<&1, &1, U32 & String,
          List<&2, U32> & (List<&2, U32> & List<&2, U32>)> <- File.read_raw(path)
        report(value)
    case _:
      IO.die(Unit, 1, "Supply one document path")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
