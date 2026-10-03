import Base
import ../src/RecoverySettings.bend as Settings
import ../src/Utf8.bend as Utf8
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def invalid(value: Settings.Choice) -> Bool:
  match value:
    case Settings.Invalid{message}: True{}
    case _: False{}

def disabled(value: Settings.Choice) -> Bool:
  match value:
    case Settings.Disabled{}: True{}
    case _: False{}

def enabled(value: Settings.Choice, supported: Bool) -> Bool:
  match value supported:
    case Settings.Enabled{host, root} True{}:
      String.eq(host, "./中文 😀 host") && String.eq(root, "./目录 😀")
    case Settings.Unavailable{host, root} False{}:
      String.eq(host, "./中文 😀 host") && String.eq(root, "./目录 😀")
    case _ _: False{}

def configured(+host: List<&2, U32>, +root: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    Check.check(invalid(Settings.decode(Done{(True{}, (Some{host}, Some{root}))})))
    Check.check(invalid(Settings.decode(Done{(False{}, (Some{host}, Some{root}))})))

def main() -> IO(Unit):
  +host = Encode.bytes(Utf8.encode("./中文 😀 host"))
  +root = Encode.bytes(Utf8.encode("./目录 😀"))
  do IO<Unit>:
    Check.check(disabled(Settings.decode(Done{(True{}, (None{}, None{}))})))
    Check.check(disabled(Settings.decode(Done{(False{}, (None{}, None{}))})))
    Check.check(enabled(Settings.decode(Done{(True{}, (Some{host}, Some{root}))}), True{}))
    Check.check(enabled(Settings.decode(Done{(False{}, (Some{host}, Some{root}))}), False{}))
    Check.check(invalid(Settings.decode(Done{(True{}, (Some{host}, None{}))})))
    Check.check(invalid(Settings.decode(Done{(True{}, (None{}, Some{root}))})))
    configured([], root)
    configured(host, [])
    configured([0], root)
    configured(host, [0])
    configured([255], root)
    configured(host, [255])
    Check.check(invalid(Settings.decode(Fail{(22, "Invalid recovery setting encoding")})))
    IO.print("Recovery settings, strict paths, and process capability checks passed")
