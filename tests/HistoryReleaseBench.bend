import Base
import ../src/TextRelease.bend as Release
import ../src/StorageHistory.bend as History
import ../src/SaveState.bend as Save
import ../src/Utf8.bend as Utf8
import ./StorageHistoryCheck.bend as Session
import ./TextReleaseBench.bend as Bench
import ./TextByteMapCheck.bend as Fixture
import ./RecoveryEditorCheck.bend as Encode

def edits(fuel: Nat, session: History.Session) -> IO(History.Session):
  match fuel:
    case 0n:
      IO.pure(History.Session, session)
    case 1n+remaining:
      do IO<History.Session>:
        next : History.Session <- Session.accepted(History.edit(session, 0n, 0n, "X"))
        edits(remaining, next)

def undo(fuel: Nat, session: History.Session) -> History.Session:
  match fuel:
    case 0n:
      session
    case 1n+remaining:
      undo(remaining, History.undo(session))

def main() -> IO(Unit):
  source = Fixture.repeat_text(16384n, String.repeat("x", 64n), "")
  initial = Save.open(Encode.bytes(Utf8.encode(source)))
  do IO<Unit>:
    session : History.Session <- Session.loaded(History.load(initial))
    changed : History.Session <- edits(20n, History.request(session))
    restored : History.Session = undo(20n, changed)
    Bench.run(32768n, Release.begin_history(restored), 0n, 0n, 0n)
