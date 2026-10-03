import Base
import ../src/OpenConfig.bend as Config

def report(value: Maybe<Maybe<String>>) -> IO(Unit):
  match value:
    case None{}:
      IO.print("invalid")
    case Some{None{}}:
      IO.print("missing")
    case Some{Some{path}}:
      IO.print("path:" ++ path)

def main() -> IO(Unit):
  do IO<Unit>:
    value : Maybe<List<&2, U32>> <- Config.read_bytes()
    report(Config.decode(value))
