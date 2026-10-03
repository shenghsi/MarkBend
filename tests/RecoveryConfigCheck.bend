import Base
import ../src/RecoveryConfig.bend as Config
import ../src/RecoverySettings.bend as Settings

def checked(value: Settings.Choice) -> IO(Unit):
  match value:
    case Settings.Disabled{}: IO.print("disabled")
    case Settings.Enabled{host, root}: IO.print("enabled:" ++ host ++ ":" ++ root)
    case Settings.Unavailable{host, root}: IO.print("unavailable:" ++ host ++ ":" ++ root)
    case Settings.Invalid{message}: IO.print("invalid")

def main() -> IO(Unit):
  do IO<Unit>:
    raw : Result<&1, &1, U32 & String,
      Bool & (Maybe<List<&2, U32>> & Maybe<List<&2, U32>>)> <- Config.read()
    checked(Settings.decode(raw))
