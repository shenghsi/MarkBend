import Base
import ../src/TextRelease.bend as Release
import ../src/StorageHistory.bend as History
import ../src/SaveState.bend as Save
import ./StorageHistoryCheck.bend as Session
import ./TextReleaseCheck.bend as Drain
import ./DirectCheck.bend as Check

def main() -> IO(Unit):
  +initial : Save.State = Save.State{[65,13,10], [255,0], 8n,
    Some{Save.Ticket{7n, [128,255]}}}
  do IO<Unit>:
    +opened : History.Session <- Session.loaded(History.load(initial))
    +first : History.Session <- Session.accepted(History.edit(opened, 0n, 1n, "中😀"))
    +second : History.Session <- Session.accepted(History.edit(first, 2n, 2n, "x"))
    Check.check(Drain.drained(64n, Release.step(8n, Release.begin_history(History.undo(second)))))
    Check.check(Session.matches(opened, "A\r\n", initial))
    Check.check(Session.matches(first, "中😀\r\n", Save.edit(initial, [228,184,173,240,159,152,128,13,10])))
    Check.check(Session.matches(second, "中😀x\r\n",
      Save.edit(initial, [228,184,173,240,159,152,128,120,13,10])))
    Check.check(Drain.drained(64n, Release.step(8n, Release.begin_history(
      History.complete(second, 7n, Save.Confirmed{})))))
    Check.check(Session.matches(History.undo(second), "中😀\r\n",
      Save.edit(initial, [228,184,173,240,159,152,128,13,10])))
    IO.print("History release preserves retained text and pending save snapshots check passed")
