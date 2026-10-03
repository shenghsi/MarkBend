import Base
import ../src/LiveParagraph.bend as Live
import ../src/AppDocument.bend as App
import ../src/StoredEditor.bend as Editor
import ../src/SaveState.bend as Flat
import ../src/Utf8.bend as Utf8
import ./StoredEditorCheck.bend as Stored
import ./RecoveryEditorCheck.bend as Encode
import ./DirectCheck.bend as Check

def Driver.mark() -> IO(Unit):
  import "./app_pump.c"
  import "./app_pump.js"

def Driver.finish() -> IO(Unit):
  import "./app_pump.c"
  import "./app_pump.js"

def state() -> Flat.State:
  Flat.request(Flat.edit(Flat.open([65]), Encode.bytes(Utf8.encode("# 中文😀\r\n"))))

def same(document: App.Document) -> Bool:
  match document:
    case App.Document{App.Resolved{requested, path, identity}, session}:
      String.eq(requested, "alias.md") && String.eq(path, "/fixture/中文.md") &&
        Flat.bytes_equal(identity, [1, 2, 3]) && Stored.matches(session, "# 中文😀\r\n", state())
    case _:
      False{}

def cycles(fuel: Nat, window: Window, document: App.Document) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        Driver.finish()
        Live.LiveParagraph.close(window)
        IO.print("Ten thousand zero-fuel app pump cycles retained complete state")
    case 1n+remaining:
      Live.LiveParagraph.run_document(0n, window, document,
        w => +d => do IO<Unit>:
          Check.check(same(d))
          Driver.mark()
          cycles(remaining, w, d))

def main() -> IO(Unit):
  do IO<Unit>:
    session : Editor.Session <- Stored.loaded(Editor.load(Flat.open([65])))
    edited : Editor.Session <- Stored.accepted(Editor.replace_source(session, "# 中文😀\r\n"))
    window : Window <- Live.LiveParagraph.open("# 中文😀\r\n")
    cycles(10000n, window, App.with_session(
      App.Resolved{"alias.md", "/fixture/中文.md", [1, 2, 3]}, Editor.request(edited)))
