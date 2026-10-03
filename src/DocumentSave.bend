import Base
import ./AppSave.bend as App
import ./ByteBuffer.bend as Bytes

# Host status: 0 confirmed, 1 old kept, 2 uncertain, 3 conflict, 4 unavailable.
# The host never edits Markdown or decides whether a close choice is permitted.
def write_raw(path: String, identity: List<&2, U32>,
  baseline: List<&2, U32>, bytes: List<&2, U32>) -> IO(U32):
  import "./document_save.c"
  import "./document_save.js"

def outcome(code: U32) -> App.Outcome:
  match code:
    case 0:
      App.Confirmed{}
    case 1:
      App.OldKept{}
    case 3:
      App.Conflict{}
    case 4:
      App.UnavailableHost{}
    case _:
      App.Uncertain{}

def write(request: App.Request) -> IO(App.Outcome):
  match request:
    case App.Request{path, identity, id, baseline, bytes}:
      do IO<App.Outcome>:
        code : U32 <- write_raw(path, identity, Bytes.materialize(baseline), Bytes.materialize(bytes))
        return outcome(code)
