import Base
import ../src/RecoveryScan.bend as Scan
import ../src/RecoveryLookup.bend as Lookup
import ../src/RecoveryEntry.bend as Entry
import ../src/SaveState.bend as Save
import ../src/RecoveryPlan.bend as Plan
import ../src/RecoveryState.bend as Recovery
import ./RecoveryRestartCheck.bend as Restart
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check

def state(edit: U32) -> Save.State:
  Save.edit(Save.open(Nil{}), [edit, 0, 255])

def write_record(value: Maybe<&2, String>, +program: String, +directory: String) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Scan fixture encoding failed")
    case Some{text}:
      do IO<Unit>:
        Restart.write_bytes(directory ++ "/document", [0])
        result : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(program, ["--save", directory], text, 4096, 30000))
        Restart.process_ok(result)

def write(+program: String, +root: String) -> IO(Unit):
  do IO<Unit>:
    write_record(Entry.encode(Entry.Entry{[42], state(65)}), program, root ++ "/a")
    write_record(Entry.encode(Entry.Entry{[43], state(66)}), program, root ++ "/b")
    IO.die(Unit, 79, "Recovery scan writer stopped")

def absent(value: Maybe<&2, List<&2, Scan.Candidate>>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def reason_kind(reason: Scan.Reason) -> U32:
  match reason:
    case Scan.UnsupportedType{}:
      0
    case Scan.ReadFailed{code}:
      1
    case Scan.InvalidRecord{}:
      2
    case Scan.ProcessFailed{code, message}:
      3

def problem_matches(problem: Scan.Rejected, name: String, kind: U32) -> Bool:
  match problem:
    case Scan.Rejected{origin, reason}:
      String.eq(origin, name) && U32.is_eq(reason_kind(reason), kind)

def has_problem(problems: List<&2, Scan.Rejected>, +name: String, +kind: U32,
  found: Bool) -> Bool:
  match problems:
    case Nil{}:
      found
    case problem <> rest:
      has_problem(rest, name, kind, found || problem_matches(problem, name, kind))

def same(entry: Entry.Entry) -> Bool:
  match entry:
    case Entry.Entry{key, recorded}:
      Save.bytes_equal(key, [42]) && States.state_equal(recorded, state(65))

def selected(duplicate: Bool, selection: Lookup.Selection) -> Bool:
  match duplicate selection:
    case False{} Lookup.Unique{entry}:
      same(entry)
    case True{} Lookup.Ambiguous{first <> second <> Nil{}}:
      same(first) && same(second)
    case _ _:
      False{}

def accepted_count(duplicate: Bool) -> Nat:
  match duplicate:
    case False{}:
      2n
    case True{}:
      3n

def other_selected(selection: Lookup.Selection) -> Bool:
  match selection:
    case Lookup.Unique{Entry.Entry{key, recorded}}:
      Save.bytes_equal(key, [43]) && States.state_equal(recorded, state(66))
    case _:
      False{}

def checked(+catalog: Scan.Catalog, +duplicate: Bool) -> IO(Unit):
  match catalog:
    case Scan.Catalog{accepted, +rejected}:
      do IO<Unit>:
        Check.check(Nat.is_eq(List.length(&2, Scan.Accepted, accepted), accepted_count(duplicate)))
        Check.check(Nat.is_eq(List.length(&2, Scan.Rejected, rejected), 5n))
        Check.check(has_problem(rejected, "636f7272757074", 2, False{}))
        Check.check(has_problem(rejected, "656d707479", 1, False{}))
        Check.check(has_problem(rejected, "616c696173", 0, False{}))
        Check.check(has_problem(rejected, "6e6f7465", 0, False{}))
        Check.check(has_problem(rejected, "6669666f", 0, False{}))
        Check.check(selected(duplicate, Lookup.lookup(Scan.entries(catalog), [42])))
        Check.check(other_selected(Lookup.lookup(Scan.entries(catalog), [43])))
        IO.print("Recovery directory validation and lookup check passed")

def completed(value: Scan.Outcome, duplicate: Bool) -> IO(Unit):
  match value:
    case Scan.Completed{catalog}:
      checked(catalog, duplicate)
    case _:
      Check.check(False{})

def all_same(entries: List<&2, Entry.Entry>, ok: Bool) -> Bool:
  match entries:
    case Nil{}:
      ok
    case entry <> rest:
      all_same(rest, ok && same(entry))

def many_selected(selection: Lookup.Selection) -> Bool:
  match selection:
    case Lookup.Ambiguous{+entries}:
      Nat.is_eq(List.length(&2, Entry.Entry, entries), 257n) && all_same(entries, True{})
    case _:
      False{}

def review_plan(value: Plan.Plan) -> Bool:
  match value:
    case Plan.Plan{requested, Plan.Review{Scan.Catalog{accepted, rejected}, selection, disk}}:
      Save.bytes_equal(requested, [42]) && Save.bytes_equal(disk, [99]) &&
        Nat.is_eq(List.length(&2, Scan.Accepted, accepted), 258n) &&
        Nat.is_eq(List.length(&2, Scan.Rejected, rejected), 5n) && many_selected(selection)
    case _:
      False{}

def contains_name(entries: List<&2, Scan.Accepted>, +name: String, found: Bool) -> Bool:
  match entries:
    case Nil{}:
      found
    case Scan.Accepted{origin, entry} <> rest:
      contains_name(rest, name, found || String.eq(origin, name))

def distinct_names(entries: List<&2, Scan.Accepted>, ok: Bool) -> Bool:
  match entries:
    case Nil{}:
      ok
    case Scan.Accepted{name, entry} <> +rest:
      distinct_names(rest, ok && Bool.not(contains_name(rest, name, False{})))

def large_completed(value: Scan.Outcome) -> IO(Unit):
  match value:
    case Scan.Completed{+catalog}:
      match catalog:
        case Scan.Catalog{+accepted, +rejected}:
          do IO<Unit>:
            Check.check(Nat.is_eq(List.length(&2, Scan.Accepted, accepted), 258n))
            Check.check(distinct_names(accepted, True{}))
            Check.check(Nat.is_eq(List.length(&2, Scan.Rejected, rejected), 5n))
            Check.check(has_problem(rejected, "636f7272757074", 2, False{}))
            Check.check(has_problem(rejected, "656d707479", 1, False{}))
            Check.check(has_problem(rejected, "616c696173", 0, False{}))
            Check.check(has_problem(rejected, "6e6f7465", 0, False{}))
            Check.check(has_problem(rejected, "6669666f", 0, False{}))
            Check.check(many_selected(Lookup.lookup(Scan.entries(catalog), [42])))
            Check.check(review_plan(Plan.prepare(Scan.Completed{catalog}, [42], [99])))
            Check.check(other_selected(Lookup.lookup(Scan.entries(catalog), [43])))
            IO.print("Larger recovery catalog and duplicate ownership check passed")
    case _:
      Check.check(False{})

def failed(value: Scan.Outcome, expected: String) -> IO(Unit):
  match value:
    case Scan.Failed{root, Scan.HostFailed{code}}:
      Check.check(String.eq(root, expected) && U32.is_eq(code, 1))
    case _:
      Check.check(False{})

def empty_completed(value: Scan.Outcome) -> IO(Unit):
  match value:
    case Scan.Completed{Scan.Catalog{Nil{}, Nil{}}}:
      IO.print("Recovery scan continued after failure")
    case _:
      Check.check(False{})

def invalid_listing(value: Scan.Outcome) -> IO(Unit):
  match value:
    case Scan.Failed{root, Scan.InvalidListing{}}:
      Check.check(String.eq(root, "root"))
    case _:
      Check.check(False{})

def transport_failure(value: Scan.Outcome) -> IO(Unit):
  match value:
    case Scan.Failed{root, Scan.TransportFailed{code, message}}:
      Check.check(String.eq(root, "root") && U32.is_eq(code, 7) && String.eq(message, "transport"))
    case _:
      Check.check(False{})

def read_transport(value: Scan.Item) -> Bool:
  match value:
    case Scan.Bad{Scan.Rejected{name, Scan.ProcessFailed{code, message}}}:
      String.eq(name, "61") && U32.is_eq(code, 7) && String.eq(message, "transport")
    case _:
      False{}

def retry(+program: String, +root: String) -> IO(Unit):
  do IO<Unit>:
    failure : Scan.Outcome <- Scan.scan(program, root)
    failed(failure, root)
    success : Scan.Outcome <- Scan.scan(program, root ++ "-retry")
    empty_completed(success)

def restored_plan(value: Plan.Plan) -> Bool:
  match value:
    case Plan.Plan{requested, Plan.Ready{Scan.Catalog{accepted, Nil{}},
      Entry.ForDocument{Recovery.Restored{restored}}}}:
      Save.bytes_equal(requested, [43]) &&
        Nat.is_eq(List.length(&2, Scan.Accepted, accepted), 2n) &&
        States.state_equal(restored, state(66))
    case _:
      False{}

def conflict_plan(value: Plan.Plan) -> Bool:
  match value:
    case Plan.Plan{requested, Plan.Ready{catalog,
      Entry.ForDocument{Recovery.Conflict{recorded, disk}}}}:
      Save.bytes_equal(requested, [43]) && States.state_equal(recorded, state(66)) &&
        Save.bytes_equal(disk, [99, 0, 255])
    case _:
      False{}

def clean_plan(+value: Scan.Outcome) -> IO(Unit):
  do IO<Unit>:
    Check.check(restored_plan(Plan.prepare(value, [43], Nil{})))
    Check.check(conflict_plan(Plan.prepare(value, [43], [99, 0, 255])))
    IO.print("Connected recovery plan and conflict check passed")

def rejected_catalog() -> Scan.Catalog:
  Scan.Catalog{[Scan.Accepted{"61", Entry.Entry{[42], state(65)}}],
    [Scan.Rejected{"62", Scan.InvalidRecord{}}]}

def review_unique(value: Plan.Plan) -> Bool:
  match value:
    case Plan.Plan{requested, Plan.Review{Scan.Catalog{accepted,
      Scan.Rejected{"62", Scan.InvalidRecord{}} <> Nil{}}, Lookup.Unique{entry}, disk}}:
      Save.bytes_equal(requested, [42]) && same(entry) && Save.bytes_equal(disk, [99]) &&
        Nat.is_eq(List.length(&2, Scan.Accepted, accepted), 1n)
    case _:
      False{}

def review_missing(value: Plan.Plan) -> Bool:
  match value:
    case Plan.Plan{requested, Plan.Review{Scan.Catalog{accepted,
      Scan.Rejected{"62", Scan.InvalidRecord{}} <> Nil{}}, Lookup.Missing{}, disk}}:
      Save.bytes_equal(requested, [44]) && Save.bytes_equal(disk, [99]) &&
        Nat.is_eq(List.length(&2, Scan.Accepted, accepted), 1n)
    case _:
      False{}

def invalid_plan(value: Plan.Plan, +expected: List<&2, U32>) -> Bool:
  match value:
    case Plan.Plan{requested, Plan.Review{catalog,
      Lookup.InvalidIdentity{invalid, entry <> Nil{}}, disk}}:
      Save.bytes_equal(requested, expected) && Save.bytes_equal(invalid, expected) &&
        same(entry) && Save.bytes_equal(disk, [99])
    case _:
      False{}

def unavailable_plan(value: Plan.Plan) -> Bool:
  match value:
    case Plan.Plan{requested, Plan.Unavailable{"root",
      Scan.TransportFailed{code, message}, disk}}:
      Save.bytes_equal(requested, [42]) && U32.is_eq(code, 7) &&
        String.eq(message, "transport") && Save.bytes_equal(disk, [99])
    case _:
      False{}

def no_match_plan(value: Plan.Plan) -> Bool:
  match value:
    case Plan.Plan{requested, Plan.NoMatch{Scan.Catalog{Nil{}, Nil{}}, disk}}:
      Save.bytes_equal(requested, [42]) && Save.bytes_equal(disk, [99])
    case _:
      False{}

def run(mode: String, program: String, atomic: String, root: String,
  duplicate: Bool) -> IO(Unit):
  match mode:
    case "write":
      write(atomic, root)
    case "retry":
      retry(program, root)
    case "large":
      do IO<Unit>:
        value : Scan.Outcome <- Scan.scan(program, root)
        large_completed(value)
    case "clean":
      do IO<Unit>:
        value : Scan.Outcome <- Scan.scan(program, root)
        clean_plan(value)
    case _:
      do IO<Unit>:
        value : Scan.Outcome <- Scan.scan(program, root)
        completed(value, duplicate)

def main() -> IO(Unit):
  do IO<Unit>:
    Check.check(review_unique(Plan.prepare(Scan.Completed{rejected_catalog()}, [42], [99])))
    Check.check(review_missing(Plan.prepare(Scan.Completed{rejected_catalog()}, [44], [99])))
    Check.check(invalid_plan(Plan.prepare(Scan.Completed{rejected_catalog()}, Nil{}, [99]), Nil{}))
    Check.check(invalid_plan(Plan.prepare(Scan.Completed{rejected_catalog()}, [256], [99]), [256]))
    Check.check(unavailable_plan(Plan.prepare(
      Scan.Failed{"root", Scan.TransportFailed{7, "transport"}}, [42], [99])))
    Check.check(no_match_plan(Plan.prepare(Scan.Completed{Scan.Catalog{Nil{}, Nil{}}}, [42], [99])))
    Check.check(read_transport(Scan.read_process(Fail{(7, "transport")}, "61")))
    invalid : Scan.Outcome <- Scan.list_result((0, ("D 61\n", "")), "unused", "root")
    invalid_listing(invalid)
    transport : Scan.Outcome <- Scan.list_process(Fail{(7, "transport")}, "unused", "root")
    transport_failure(transport)
    Check.check(absent(Scan.parse("")))
    Check.check(absent(Scan.parse("D 61\n")))
    Check.check(absent(Scan.parse("END")))
    Check.check(absent(Scan.parse("END\nD 61\nEND\n")))
    Check.check(absent(Scan.parse("D 0g\nEND\n")))
    Check.check(absent(Scan.parse("D \nEND\n")))
    program : String <- IO.try(String, IO.get_env("MARKBEND_DIRECTORY_HOST"))
    atomic : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    root : String <- IO.try(String, IO.get_env("MARKBEND_SCAN_ROOT"))
    mode : String <- IO.try(String, IO.get_env("MARKBEND_SCAN_MODE"))
    duplicate : String <- IO.try(String, IO.get_env("MARKBEND_SCAN_DUPLICATE"))
    run(mode, program, atomic, root, String.eq(duplicate, "yes"))
