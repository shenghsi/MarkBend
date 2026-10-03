import Base
import ../src/PersistentSave.bend as Persistent
import ../src/SaveState.bend as Save
import ../src/TextStorage.bend as Storage
import ../src/ByteBuffer.bend as Bytes
import ../src/BlockIndex.bend as Index
import ./SaveStateCheck.bend as Reference
import ./TextStorageCheck.bend as Text
import ./DirectCheck.bend as Check
import ./TextByteMapCheck.bend as MapCheck

def loaded(value: Maybe<&2, Persistent.State>) -> Persistent.State:
  match value:
    case Some{state}:
      state
    case None{}:
      Persistent.State{Bytes.Buffer{Index.Empty{}}, Bytes.Buffer{Index.Empty{}}, 0n, None{}}

def buffer(snapshot: Storage.Snapshot) -> Persistent.State:
  match snapshot:
    case Storage.Snapshot{+bytes, mapping}:
      Persistent.State{bytes, bytes, 0n, None{}}

def edit(state: Persistent.State, snapshot: Storage.Snapshot) -> Persistent.State:
  match snapshot:
    case Storage.Snapshot{bytes, mapping}:
      Persistent.edit(state, bytes)

def equal(state: Persistent.State, expected: Save.State) -> Bool:
  Reference.state_equal(Persistent.materialize(state), expected)

def observed(state: Persistent.State) -> Bytes.Buffer:
  match state:
    case Persistent.State{current, saved, next, pending}:
      current

def reconcile_case(+state: Persistent.State, +value: Bytes.Buffer, +id: Nat, +synced: Bool) -> Bool:
  equal(Persistent.reconcile(state, id, value, synced),
    Save.reconcile(Persistent.materialize(state), id, Bytes.materialize(value), synced))

def absent(value: Maybe<&2, Persistent.State>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def decoded(value: Maybe<&2, Persistent.State>, expected: Save.State) -> Bool:
  match value:
    case Some{state}:
      equal(state, expected)
    case None{}:
      False{}

def record_case(value: Maybe<&2, String>, +expected: Save.State) -> Bool:
  match value:
    case Some{+text}:
      decoded(Persistent.decode_record(text), expected) &&
        absent(Persistent.decode_record(text ++ "x"))
    case None{}:
      False{}

def main() -> IO(Unit):
  +large = Text.snapshot(Storage.from_text(MapCheck.repeat_text(16384n, String.repeat("x", 64n), "")))
  +large_state = buffer(large)
  +large_edit = Text.accepted(Storage.replace(large, 513n, 514n, "x"))
  +original = Text.snapshot(Storage.from_text("A中😀\r\n\0"))
  +changed = Text.accepted(Storage.replace(original, 1n, 2n, "新"))
  +later = Text.accepted(Storage.replace(changed, 0n, 0n, "later"))
  +opened = buffer(original)
  +saving = Persistent.request(edit(opened, changed))
  +current = edit(saving, later)
  +flat = Persistent.materialize(current)
  +uncertain = Persistent.complete(current, 0n, Save.ReplacementUncertain{})
  +done = Persistent.complete(current, 0n, Save.Confirmed{})
  +next = Persistent.request(done)
  +raw : Save.State = Save.State{[255, 0], [13, 10], 8n, Some{Save.Ticket{7n, [128, 255]}}}
  do IO<Unit>:
    Check.check(absent(Persistent.load(Save.State{[256], [], 0n, None{}})))
    Check.check(absent(Persistent.load(Save.State{[], [256], 0n, None{}})))
    Check.check(absent(Persistent.load(Save.State{[], [], 1n, Some{Save.Ticket{0n, [256]}}})))
    Check.check(record_case(Persistent.encode_record(current), flat))
    Check.check(record_case(Persistent.encode_record(loaded(Persistent.load(raw))), raw))
    Check.check(record_case(Persistent.encode_record(large_state), Persistent.materialize(large_state)))
    Check.check(absent(Persistent.decode_record("MBR2\ninvalid\n")))
    Check.check(Bool.not(Persistent.dirty(edit(large_state, large_edit))))
    Check.check(Persistent.dirty(edit(large_state,
      Text.accepted(Storage.replace(large, 1048575n, 1048576n, "y")))))
    Check.check(reconcile_case(uncertain, observed(edit(opened, changed)), 0n, True{}))
    Check.check(reconcile_case(uncertain, observed(opened), 0n, True{}))
    Check.check(reconcile_case(uncertain, observed(current), 0n, True{}))
    Check.check(reconcile_case(uncertain, observed(saving), 99n, True{}))
    Check.check(reconcile_case(uncertain, observed(saving), 0n, False{}))
    Check.check(Bool.not(Persistent.dirty(opened)))
    Check.check(Persistent.dirty(done))
    Check.check(Bool.not(Persistent.dirty(edit(done, changed))))
    Check.check(equal(loaded(Persistent.load(flat)), flat))
    Check.check(equal(uncertain, flat))
    Check.check(equal(Persistent.request(uncertain), flat))
    Check.check(equal(done, Save.complete(flat, 0n, Save.Confirmed{})))
    Check.check(equal(Persistent.complete(current, 0n, Save.OldKept{}),
      Save.complete(flat, 0n, Save.OldKept{})))
    Check.check(equal(Persistent.complete(current, 99n, Save.Confirmed{}), flat))
    Check.check(equal(Persistent.complete(next, 0n, Save.Confirmed{}),
      Persistent.materialize(next)))
    Check.check(equal(Persistent.complete(next, 1n, Save.Confirmed{}),
      Save.complete(Persistent.materialize(next), 1n, Save.Confirmed{})))
    Check.check(equal(loaded(Persistent.load(Save.State{[255, 0], [13, 10], 8n,
      Some{Save.Ticket{7n, [128, 255]}}})),
      Save.State{[255, 0], [13, 10], 8n, Some{Save.Ticket{7n, [128, 255]}}}))
    Check.check(Text.matches(original, "A中😀\r\n\0"))
    Check.check(Text.matches(changed, "A新😀\r\n\0"))
    IO.print("Persistent save requests and completion snapshots check passed")
