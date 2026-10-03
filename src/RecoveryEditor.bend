import Base
import ./RecoveryPlan.bend as Plan
import ./RecoveryScan.bend as Scan
import ./RecoveryEntry.bend as Entry
import ./RecoveryState.bend as Recovery
import ./SaveState.bend as Save
import ./DirectState.bend as Editor
import ./Utf8.bend as Utf8

type Outcome is Data:
  Opened{requested: List<&2, U32>, catalog: Scan.Catalog, save: Save.State,
    editor: Editor.Session}
  Blocked{plan: Plan.Plan}
  RejectedEdit{previous: Outcome, attempted: Editor.Session}

def current(state: Save.State) -> List<&2, U32>:
  match state:
    case Save.State{bytes, saved, next, pending}:
      bytes

def decoded(text: Maybe<&2, String>, plan: Plan.Plan, requested: List<&2, U32>,
  catalog: Scan.Catalog, save: Save.State) -> Outcome:
  match text:
    case Some{source}:
      Opened{requested, catalog, save, Editor.start(source)}
    case None{}:
      Blocked{plan}

# Open a new editor model only after the recovery plan permits it. Retain exact
# save bytes independently of its text projection. Blocked results keep the
# complete plan. No file is written, and no existing editor model is replaced.
def open(+plan: Plan.Plan) -> Outcome:
  match plan:
    case Plan.Plan{requested, Plan.NoMatch{catalog, +disk}}:
      decoded(Utf8.decode(disk), plan, requested, catalog, Save.open(disk))
    case Plan.Plan{requested, Plan.Ready{catalog,
      Entry.ForDocument{Recovery.Restored{+save}}}}:
      decoded(Utf8.decode(current(save)), plan, requested, catalog, save)
    case _:
      Blocked{plan}

def encoded(bytes: Maybe<&2, List<&2, U32>>, previous: Outcome,
  requested: List<&2, U32>, catalog: Scan.Catalog, save: Save.State,
  next: Editor.Session) -> Outcome:
  match bytes:
    case Some{current}:
      Opened{requested, catalog, Save.edit(save, current), next}
    case None{}:
      RejectedEdit{previous, next}

# This first connection encodes a complete source snapshot after each command.
# It is a correctness baseline; incremental byte updates are still required
# before this can satisfy the product's local-edit performance target.
def sync(+previous: Outcome, +next: Editor.Session) -> Outcome:
  match previous:
    case Opened{requested, catalog, save, editor}:
      encoded(Utf8.encode(Editor.source(Editor.current(next))), previous,
        requested, catalog, save, next)
    case _:
      previous

def edit(+value: Outcome, start: Nat, end: Nat, text: String) -> Outcome:
  match value:
    case Opened{requested, catalog, save, editor}:
      sync(value, Editor.edit(editor, start, end, text))
    case _:
      value

def undo(+value: Outcome) -> Outcome:
  match value:
    case Opened{requested, catalog, save, editor}:
      sync(value, Editor.undo(editor))
    case _:
      value

def redo(+value: Outcome) -> Outcome:
  match value:
    case Opened{requested, catalog, save, editor}:
      sync(value, Editor.redo(editor))
    case _:
      value

def select(value: Outcome, start: Nat, end: Nat) -> Outcome:
  match value:
    case Opened{requested, catalog, save, editor}:
      Opened{requested, catalog, save, Editor.select(editor, start, end)}
    case _:
      value

def request(value: Outcome) -> Outcome:
  match value:
    case Opened{requested, catalog, save, editor}:
      Opened{requested, catalog, Save.request(save), editor}
    case _:
      value

def complete(value: Outcome, id: Nat, result: Save.Outcome) -> Outcome:
  match value:
    case Opened{requested, catalog, save, editor}:
      Opened{requested, catalog, Save.complete(save, id, result), editor}
    case _:
      value
