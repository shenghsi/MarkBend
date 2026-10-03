import Base
import ../src/InitialFile.bend as Reader
import ../src/InitialOpen.bend as Initial
import ../src/ResolvedOpen.bend as Open
import ../src/AppDocument.bend as App
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./ResolvedFileCheck.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def checked(value: Initial.Outcome, +requested: String, +resolved: String,
  +mode: String) -> IO(Unit):
  match value:
    case Initial.Opened{Initial.Initial{document, disk}}:
      do IO<Unit>:
        Check.check(Save.bytes_equal(disk, Encode.bytes(Utf8.encode(Fixture.source(mode)))))
        Fixture.checked(Open.Opened{document}, requested, resolved, mode)
    case Initial.Failed{reason}:
      Fixture.checked(reason, requested, resolved, mode)

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case program <> +requested <> +resolved <> +mode <> Nil{}:
      do IO<Unit>:
        value : Initial.Outcome <- Reader.read(requested)
        checked(value, requested, resolved, mode)
    case _:
      IO.die(Unit, 1, "Supply requested path, resolved path, and mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
