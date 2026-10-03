import Base
import ./Utf8.bend as Utf8

# Read only the requested startup path. Decode native bytes without replacement.
def read_bytes() -> IO(Maybe<List<&2, U32>>):
  import "./open_config.c"
  import "./open_config.js"

def decoded(value: Maybe<&2, String>) -> Maybe<Maybe<String>>:
  match value:
    case None{}:
      None{}
    case Some{path}:
      Some{Some{path}}

def decode(value: Maybe<List<&2, U32>>) -> Maybe<Maybe<String>>:
  match value:
    case None{}:
      Some{None{}}
    case Some{bytes}:
      decoded(Utf8.decode(bytes))
