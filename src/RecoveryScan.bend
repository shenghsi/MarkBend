import Base
import ./RecoveryEntry.bend as Entry
import ./RecoveryRecord.bend as Record

type Candidate is Data:
  Directory{name: String}
  Unsupported{name: String}

type Reason is Data:
  UnsupportedType{}
  ReadFailed{code: U32}
  InvalidRecord{}
  ProcessFailed{code: U32, message: String}

type Accepted is Data:
  Accepted{name: String, entry: Entry.Entry}

type Rejected is Data:
  Rejected{name: String, reason: Reason}

type Catalog is Data:
  Catalog{accepted: List<&2, Accepted>, rejected: List<&2, Rejected>}

type Failure is Data:
  HostFailed{code: U32}
  InvalidListing{}
  TransportFailed{code: U32, message: String}

type Outcome is Data:
  Completed{catalog: Catalog}
  Failed{root: String, reason: Failure}

type Item is Data:
  Good{value: Accepted}
  Bad{value: Rejected}

def line_gate(ok: Bool, name: String, directory: Bool) -> Maybe<&2, Candidate>:
  match ok directory:
    case True{} True{}:
      Some{Directory{name}}
    case True{} False{}:
      Some{Unsupported{name}}
    case False{} _:
      None{}

def line_bytes(value: Maybe<&2, List<&2, U32>>, name: String,
  directory: Bool) -> Maybe<&2, Candidate>:
  match value:
    case Some{bytes}:
      line_gate(Entry.nonempty(bytes), name, directory)
    case None{}:
      None{}

def line(text: String) -> Maybe<&2, Candidate>:
  match text:
    case SCon{'D', SCon{' ', +name}}:
      line_bytes(Record.read_hex(name), name, True{})
    case SCon{'X', SCon{' ', +name}}:
      line_bytes(Record.read_hex(name), name, False{})
    case _:
      None{}

def push(value: Maybe<&2, Candidate>, entries: Maybe<&2, List<&2, Candidate>>) ->
  Maybe<&2, List<&2, Candidate>>:
  match value entries:
    case Some{candidate} Some{rest}:
      Some{Con{candidate, rest}}
    case _ _:
      None{}

def reverse_checked(value: Maybe<&2, List<&2, Candidate>>) -> Maybe<&2, List<&2, Candidate>>:
  match value:
    case Some{entries}:
      Some{List.reverse(&2, Candidate, entries)}
    case None{}:
      None{}

def parse_parts(parts: List<&2, String>, acc: Maybe<&2, List<&2, Candidate>>) ->
  Maybe<&2, List<&2, Candidate>>:
  match parts:
    case "END" <> SNil{} <> Nil{}:
      reverse_checked(acc)
    case head <> rest:
      parse_parts(rest, push(line(head), acc))
    case Nil{}:
      None{}

def parse(text: String) -> Maybe<&2, List<&2, Candidate>>:
  parse_parts(Record.record_parts(text, "", Nil{}), Some{Nil{}})

def decoded(value: Maybe<&2, Entry.Entry>, name: String) -> Item:
  match value:
    case Some{entry}:
      Good{Accepted{name, entry}}
    case None{}:
      Bad{Rejected{name, InvalidRecord{}}}

def read_gate(ok: Bool, code: U32, text: String, name: String) -> Item:
  match ok:
    case True{}:
      decoded(Entry.decode(text), name)
    case False{}:
      Bad{Rejected{name, ReadFailed{code}}}

def read_result(result: U32 & (String & String), name: String) -> Item:
  match result:
    case (+code, (text, error)):
      read_gate(U32.is_eq(code, 0), code, text, name)

def add(item: Item, catalog: Catalog) -> Catalog:
  match item catalog:
    case Good{entry} Catalog{accepted, rejected}:
      Catalog{Con{entry, accepted}, rejected}
    case Bad{problem} Catalog{accepted, rejected}:
      Catalog{accepted, Con{problem, rejected}}

def read_process(result: Result<&1, &1, U32 & String, U32 & (String & String)>,
  name: String) -> Item:
  match result:
    case Done{value}:
      read_result(value, name)
    case Fail{(code, message)}:
      Bad{Rejected{name, ProcessFailed{code, message}}}

def finish(catalog: Catalog) -> Catalog:
  match catalog:
    case Catalog{accepted, rejected}:
      Catalog{List.reverse(&2, Accepted, accepted), List.reverse(&2, Rejected, rejected)}

def read_candidates(candidates: List<&2, Candidate>, +program: String, +root: String,
  catalog: Catalog) -> IO(Catalog):
  match candidates:
    case Nil{}:
      IO.pure(Catalog, finish(catalog))
    case Directory{+name} <> rest:
      do IO<Catalog>:
        result : Result<&1, &1, U32 & String, U32 & (String & String)> <-
          Process.run(program, ["--read", root, name], "", 8388608, 30000)
        read_candidates(rest, program, root, add(read_process(result, name), catalog))
    case Unsupported{name} <> rest:
      read_candidates(rest, program, root, add(Bad{Rejected{name, UnsupportedType{}}}, catalog))

def listed(value: Maybe<&2, List<&2, Candidate>>, program: String, root: String) -> IO(Outcome):
  match value:
    case Some{candidates}:
      do IO<Outcome>:
        catalog : Catalog <- read_candidates(candidates, program, root, Catalog{Nil{}, Nil{}})
        return Completed{catalog}
    case None{}:
      IO.pure(Outcome, Failed{root, InvalidListing{}})

def list_gate(ok: Bool, code: U32, text: String, program: String, root: String) -> IO(Outcome):
  match ok:
    case True{}:
      listed(parse(text), program, root)
    case False{}:
      IO.pure(Outcome, Failed{root, HostFailed{code}})

def list_result(result: U32 & (String & String), program: String, root: String) -> IO(Outcome):
  match result:
    case (+code, (text, error)):
      list_gate(U32.is_eq(code, 0), code, text, program, root)

def list_process(result: Result<&1, &1, U32 & String, U32 & (String & String)>,
  program: String, root: String) -> IO(Outcome):
  match result:
    case Done{value}:
      list_result(value, program, root)
    case Fail{(code, message)}:
      IO.pure(Outcome, Failed{root, TransportFailed{code, message}})

def scan(+program: String, +root: String) -> IO(Outcome):
  do IO<Outcome>:
    result : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run(program, ["--list", root], "", 1048576, 30000)
    list_process(result, program, root)

def entries_go(accepted: List<&2, Accepted>, acc: List<&2, Entry.Entry>) -> List<&2, Entry.Entry>:
  match accepted:
    case Nil{}:
      List.reverse(&2, Entry.Entry, acc)
    case Accepted{name, entry} <> rest:
      entries_go(rest, Con{entry, acc})

def entries(catalog: Catalog) -> List<&2, Entry.Entry>:
  match catalog:
    case Catalog{accepted, rejected}:
      entries_go(accepted, Nil{})
