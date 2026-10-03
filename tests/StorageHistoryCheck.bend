import Base
import ../src/StorageHistory.bend as History
import ../src/PersistentSave.bend as Save
import ../src/SaveState.bend as Flat
import ./TextStorageCheck.bend as Text
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check

def loaded(value: Maybe<&2, History.Session>) -> IO(History.Session):
  match value:
    case Some{session}:
      IO.pure(History.Session, session)
    case None{}:
      IO.die(History.Session, 1, "History load failed")

def accepted(value: History.EditResult) -> IO(History.Session):
  match value:
    case History.Accepted{session}:
      IO.pure(History.Session, session)
    case History.Rejected{session}:
      IO.die(History.Session, 1, "History edit failed")

def matches(session: History.Session, source: String, expected: Flat.State) -> Bool:
  match session:
    case History.Session{current, undo, redo, save, identity}:
      Text.matches(current, source) && States.state_equal(Save.materialize(save), expected)

def empty_history(session: History.Session) -> Bool:
  match session:
    case History.Session{current, Nil{}, Nil{}, save, identity}:
      True{}
    case _:
      False{}

def absent(value: Maybe<&2, History.Session>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def main() -> IO(Unit):
  +initial : Flat.State = Flat.State{[65, 13, 10], [255, 0], 8n,
    Some{Flat.Ticket{7n, [128, 255]}}}
  do IO<Unit>:
    +opened : History.Session <- loaded(History.load(initial))
    +first : History.Session <- accepted(History.edit(opened, 0n, 1n, "中😀"))
    +second : History.Session <- accepted(History.edit(first, 2n, 2n, "x"))
    +branched : History.Session <- accepted(History.edit(History.undo(second), 0n, 1n, "B"))
    +fresh : History.Session <- loaded(History.load(Flat.open([65,13,10])))
    +saving : History.Session <- accepted(History.edit(fresh, 0n, 1n, "中😀"))
    +later : History.Session <- accepted(History.edit(History.request(saving), 2n, 2n, "x"))
    +equal_edit : History.Session <- accepted(History.edit(fresh, 0n, 1n, "A"))
    +confirmed : History.Session <- IO.pure(History.Session,
      History.complete(later, 0n, Flat.Confirmed{}))
    +new_branch : History.Session <- accepted(History.edit(History.undo(History.undo(confirmed)), 0n, 1n, "B"))
    Check.check(Bool.not(History.dirty(fresh)))
    Check.check(Bool.not(History.dirty(equal_edit)))
    Check.check(History.dirty(History.undo(later)))
    Check.check(Bool.not(History.dirty(History.undo(confirmed))))
    Check.check(History.dirty(new_branch))
    Check.check(History.dirty(History.complete(later, 99n, Flat.Confirmed{})))
    Check.check(History.dirty(History.complete(later, 0n, Flat.ReplacementUncertain{})))
    Check.check(History.dirty(History.complete(later, 0n, Flat.OldKept{})))
    Check.check(empty_history(opened))
    Check.check(matches(opened, "A\r\n", initial))
    Check.check(matches(History.undo(first), "A\r\n", initial))
    Check.check(matches(History.redo(History.undo(first)), "中😀\r\n",
      Flat.edit(initial, [228,184,173,240,159,152,128,13,10])))
    Check.check(matches(History.redo(branched), "B😀\r\n",
      Flat.edit(initial, [66,240,159,152,128,13,10])))
    Check.check(matches(History.request(second), "中😀x\r\n",
      Flat.edit(initial, [228,184,173,240,159,152,128,120,13,10])))
    Check.check(matches(History.undo(History.complete(second, 7n, Flat.Confirmed{})), "中😀\r\n",
      Flat.State{[228,184,173,240,159,152,128,13,10], [128,255], 8n, None{}}))
    Check.check(absent(History.load(Flat.open([255]))))
    Check.check(matches(History.undo(later), "中😀\r\n",
      Flat.State{[228,184,173,240,159,152,128,13,10], [65,13,10], 1n,
        Some{Flat.Ticket{0n, [228,184,173,240,159,152,128,13,10]}}}))
    Check.check(matches(History.undo(History.complete(later, 0n, Flat.Confirmed{})), "中😀\r\n",
      Flat.State{[228,184,173,240,159,152,128,13,10],
        [228,184,173,240,159,152,128,13,10], 1n, None{}}))
    Check.check(matches(History.redo(History.undo(History.complete(later, 0n, Flat.Confirmed{}))),
      "中😀x\r\n", Flat.State{[228,184,173,240,159,152,128,120,13,10],
        [228,184,173,240,159,152,128,13,10], 1n, None{}}))
    IO.print("Persistent text history and save snapshots check passed")
