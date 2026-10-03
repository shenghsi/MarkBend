import Base
import ./AppSaveAs.bend as As
import ./Utf8.bend as Utf8

def resolve_raw(path: String) -> IO(Result<&1, &1, U32 & String,
  List<&2, U32> & (List<&2, U32> & List<&2, U32>)>):
  import "./new_file_target.c"
  import "./new_file_target.js"

def checked(ok: Bool, target: As.Target) -> As.Candidate:
  match ok:
    case True{}:
      As.Validated{target}
    case False{}:
      As.Unavailable{}

def decoded(value: Maybe<&2, String>, requested: String, identity: List<&2, U32>, parent: List<&2, U32>) -> As.Candidate:
  match value:
    case Some{path}:
      +target : As.Target = As.Target{requested, path, identity, parent}
      checked(As.valid(target), target)
    case None{}:
      As.Unavailable{}

def received(value: Result<&1, &1, U32 & String,
  List<&2, U32> & (List<&2, U32> & List<&2, U32>)>, requested: String) -> As.Candidate:
  match value:
    case Done{(path, (identity, parent))}:
      decoded(Utf8.decode(path), requested, identity, parent)
    case Fail{(code, message)}:
      As.Rejected{message}

def resolve(+path: String) -> IO(As.Candidate):
  do IO<As.Candidate>:
    value : Result<&1, &1, U32 & String, List<&2, U32> & (List<&2, U32> & List<&2, U32>)> <- resolve_raw(path)
    return received(value, path)
