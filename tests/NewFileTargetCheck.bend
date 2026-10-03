import Base
import ../src/NewFileTarget.bend as Host
import ../src/AppSaveAs.bend as As
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ../src/SaveState.bend as Flat
import ./DirectCheck.bend as Check

def unavailable(value: As.Candidate) -> Bool:
  match value:
    case As.Unavailable{}:
      True{}
    case _:
      False{}

def invalid_decoding() -> Bool:
  unavailable(Host.received(Done{([255], ([9], [8]))}, "requested"))

def matches(value: As.Candidate, requested: String, +expected: String, expected_parent: String) -> Bool:
  match value:
    case As.Validated{+target}:
      match target:
        case As.Target{actual_request, path, key, parent}:
          As.valid(target) && String.eq(actual_request, requested) &&
            String.eq(path, expected) && Flat.bytes_equal(key, Encode.bytes(Utf8.encode("PATH1:" ++ expected))) &&
            Flat.bytes_equal(parent, Encode.bytes(Utf8.encode(expected_parent)))
    case As.Unavailable{}:
      String.eq(expected, "-")
    case As.Rejected{message}:
      String.eq(expected, "-")
    case _:
      False{}

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> +requested <> expected <> expected_parent <> Nil{}:
      do IO<Unit>:
        Check.check(invalid_decoding())
        value : As.Candidate <- Host.resolve(requested)
        Check.check(matches(value, requested, expected, expected_parent))
        IO.print("New-file target host result passed")
    case _:
      IO.die(Unit, 1, "Supply requested path, expected resolved path or -, and parent identity")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
