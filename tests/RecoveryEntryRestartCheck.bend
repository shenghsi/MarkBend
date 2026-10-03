import Base
import ../src/RecoveryEntry.bend as Entry
import ../src/RecoveryState.bend as Recovery
import ../src/SaveState.bend as Save
import ../src/RecoveryRecord.bend as Record
import ../src/RecoveryLookup.bend as Lookup
import ./RecoveryLargeRestartCheck.bend as Large
import ./RecoveryRestartCheck.bend as Restart
import ./SaveStateCheck.bend as States
import ./DirectCheck.bend as Check

def identity_value(value: Maybe<&2, List<&2, U32>>) -> IO(List<&2, U32>):
  match value:
    case Some{bytes}:
      IO.pure(List<&2, U32>, bytes)
    case None{}:
      IO.die(List<&2, U32>, 1, "Invalid host identity")

def identity_text(parts: List<&2, String>) -> IO(List<&2, U32>):
  match parts:
    case text <> SNil{} <> Nil{}:
      identity_value(Record.read_hex(text))
    case _:
      IO.die(List<&2, U32>, 1, "Invalid host identity output")

def identity_result(result: U32 & (String & String)) -> IO(List<&2, U32>):
  match result:
    case (code, (text, error)):
      do IO<List<&2, U32>>:
        Check.check(U32.is_eq(code, 0))
        identity_text(Record.record_parts(text, "", Nil{}))

def identity(program: String, path: String) -> IO(List<&2, U32>):
  do IO<List<&2, U32>>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(program, [path], "", 16384, 30000))
    identity_result(result)

def source_path(owner: Bool, root: String) -> String:
  match owner:
    case True{}:
      root ++ "/a/document"
    case False{}:
      root ++ "/b/document"

def write_source(+program: String, +directory: String) -> IO(Unit):
  do IO<Unit>:
    Restart.write_bytes(directory ++ "/document", Large.bytes(65))
    synced : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(program, ["--sync", directory], "", 4096, 30000))
    Restart.process_ok(synced)

def save_entry(value: Maybe<&2, String>, +program: String, +root: String) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Recovery entry encoding failed")
    case Some{text}:
      do IO<Unit>:
        Restart.write_bytes(root ++ "/a/journal/document", [0])
        saved : U32 & (String & String) <- IO.try(U32 & (String & String),
          Process.run(program, ["--save", root ++ "/a/journal"], text, 4096, 30000))
        Restart.process_ok(saved)
        IO.die(Unit, 79, "Recovery entry writer stopped")

def persist(+program: String, identity_host: String, +root: String) -> IO(Unit):
  do IO<Unit>:
    write_source(program, root ++ "/a")
    write_source(program, root ++ "/b")
    owner_key : List<&2, U32> <- identity(identity_host, root ++ "/a/document")
    save_entry(Entry.encode(Entry.Entry{owner_key, Large.recorded()}), program, root)

def correct(owner: Bool, result: Entry.Decision, owner_key: List<&2, U32>) -> Bool:
  match owner result:
    case True{} Entry.ForDocument{Recovery.Restored{state}}:
      States.state_equal(state, Save.result(Large.recorded(), 0n, False{}))
    case False{} Entry.WrongDocument{Entry.Entry{identity, state}, disk}:
      Save.bytes_equal(identity, owner_key) && States.state_equal(state, Large.recorded()) &&
        Save.bytes_equal(disk, Large.bytes(65))
    case _ _:
      False{}

def source(result: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  entry: Entry.Entry, owner: Bool, requested: List<&2, U32>, owner_key: List<&2, U32>) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        disk : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        Check.check(correct(owner, Entry.recover(requested, entry, disk), owner_key))
        IO.print("One-MiB recovery entry restart check passed")

def matches(entry: Entry.Entry, owner_key: List<&2, U32>) -> Bool:
  match entry:
    case Entry.Entry{identity, state}:
      Save.bytes_equal(identity, owner_key) && States.state_equal(state, Large.recorded())

def selected_for_owner(owner: Bool, selection: Lookup.Selection,
  owner_key: List<&2, U32>) -> Bool:
  match owner selection:
    case True{} Lookup.Unique{entry}:
      matches(entry, owner_key)
    case False{} Lookup.Missing{}:
      True{}
    case _ _:
      False{}

def read_selected(+entry: Entry.Entry, root: String, +owner: Bool,
  +requested: List<&2, U32>, +owner_key: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    Check.check(matches(entry, owner_key))
    Check.check(selected_for_owner(owner, Lookup.lookup([entry], requested), owner_key))
    file : File <- IO.try(File, File.open(source_path(owner, root), "r"))
    result : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 1048577)
    source(result, entry, owner, requested, owner_key)

def decoded(value: Maybe<&2, Entry.Entry>, +identity_host: String, +root: String, +owner: Bool) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "Persisted recovery entry rejected")
    case Some{+entry}:
      do IO<Unit>:
        owner_key : List<&2, U32> <- identity(identity_host, root ++ "/a/document")
        requested : List<&2, U32> <- identity(identity_host, source_path(owner, root))
        read_selected(entry, root, owner, requested, owner_key)

def record(result: File & Result<&1, &1, U32 & String, String>, identity_host: String, root: String,
  owner: Bool) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        text : String <- IO.pass(String, value)
        decoded(Entry.decode(text), identity_host, root, owner)

def run(write: Bool, program: String, identity_host: String, +root: String, owner: Bool) -> IO(Unit):
  match write:
    case True{}:
      persist(program, identity_host, root)
    case False{}:
      do IO<Unit>:
        file : File <- IO.try(File, File.open(root ++ "/a/journal/document", "r"))
        result : File & Result<&1, &1, U32 & String, String> <- File.read(file, 8388609)
        record(result, identity_host, root, owner)

def main() -> IO(Unit):
  do IO<Unit>:
    program : String <- IO.try(String, IO.get_env("MARKBEND_ATOMIC_HOST"))
    identity_host : String <- IO.try(String, IO.get_env("MARKBEND_IDENTITY_HOST"))
    root : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_DIRECTORY"))
    mode : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_MODE"))
    owner : String <- IO.try(String, IO.get_env("MARKBEND_RECOVERY_OWNER"))
    run(String.eq(mode, "write"), program, identity_host, root, String.eq(owner, "a"))
