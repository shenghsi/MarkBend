import Base
import ../src/SaveState.bend as Save
import ./DirectCheck.bend as Check

def pending_equal(a: Maybe<&2, Save.Ticket>, b: Maybe<&2, Save.Ticket>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{Save.Ticket{x, bytes}} Some{Save.Ticket{y, expected}}:
      Nat.is_eq(x, y) && Save.bytes_equal(bytes, expected)
    case _ _:
      False{}

def state_equal(a: Save.State, b: Save.State) -> Bool:
  match a b:
    case Save.State{current, saved, next, pending} Save.State{ec, es, en, ep}:
      Save.bytes_equal(current, ec) && Save.bytes_equal(saved, es) &&
        Nat.is_eq(next, en) && pending_equal(pending, ep)

def main() -> IO(Unit):
  +opened = Save.open([65, 13, 10, 0, 255])
  +edited = Save.edit(opened, [66, 0, 255])
  +saving = Save.request(edited)
  +new_edit = Save.edit(saving, [67, 0, 255])
  +done = Save.result(new_edit, 0n, True{})
  +new_request = Save.request(done)
  +stale = Save.result(new_request, 0n, True{})
  +failed = Save.result(new_edit, 0n, False{})
  +uncertain = Save.complete(new_edit, 0n, Save.ReplacementUncertain{})
  do IO<Unit>:
    Check.check(state_equal(Save.reconcile(uncertain, 0n, [66, 0, 255], True{}), done))
    Check.check(state_equal(Save.reconcile(uncertain, 0n, [65, 13, 10, 0, 255], True{}), failed))
    Check.check(state_equal(Save.reconcile(uncertain, 0n, [88, 0, 255], True{}), uncertain))
    Check.check(state_equal(Save.reconcile(uncertain, 0n, [66, 0, 255], False{}), uncertain))
    Check.check(state_equal(Save.reconcile(uncertain, 99n, [66, 0, 255], True{}), uncertain))
    Check.check(state_equal(uncertain, new_edit))
    Check.check(state_equal(Save.request(uncertain), uncertain))
    Check.check(state_equal(Save.complete(uncertain, 0n, Save.Confirmed{}), done))
    Check.check(state_equal(Save.complete(uncertain, 0n, Save.OldKept{}), failed))
    Check.check(state_equal(saving, Save.State{[66, 0, 255], [65, 13, 10, 0, 255],
      1n, Some{Save.Ticket{0n, [66, 0, 255]}}}))
    Check.check(state_equal(Save.request(new_edit), new_edit))
    Check.check(state_equal(done, Save.State{[67, 0, 255], [66, 0, 255], 1n, None{}}))
    Check.check(state_equal(failed, Save.State{[67, 0, 255], [65, 13, 10, 0, 255], 1n, None{}}))
    Check.check(state_equal(stale, new_request))
    Check.check(state_equal(Save.result(new_request, 0n, False{}), new_request))
    Check.check(state_equal(Save.result(done, 0n, False{}), done))
    Check.check(state_equal(Save.result(new_request, 1n, True{}),
      Save.State{[67, 0, 255], [67, 0, 255], 2n, None{}}))
    Check.check(Bool.not(Save.dirty(opened)))
    Check.check(Save.dirty(edited))
    Check.check(Save.dirty(done))
    Check.check(Bool.not(Save.dirty(Save.result(saving, 0n, True{}))))
    Check.check(Save.dirty(failed))
    Check.check(Bool.not(Save.dirty(Save.result(stale, 1n, True{}))))
    Check.check(Bool.not(Save.dirty(Save.edit(done, [66, 0, 255]))))
    IO.print("Save state batch passed")
