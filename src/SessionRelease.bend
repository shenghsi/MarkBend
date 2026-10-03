import Base
import ./StoredEditor.bend as Editor

# EXPERIMENT ONLY: IO.fork returns quickly, but a delayed heartbeat still
# waits for disposal on native Bend. This is not a responsive close strategy.

def release(session: Editor.Session) -> Bool:
  True{}

# Keep ownership in the task continuation until an effect runs. Do not drop
# the session while constructing the task passed to IO.fork.
def task(session: Editor.Session) -> IO(Bool):
  do IO<Bool>:
    ready : Nat <- IO.now()
    return release(session)

# The caller owns the completion channel and must join it before shutdown.
def begin(session: Editor.Session) -> IO(Chan(Bool)):
  IO.fork(Bool, task(session))

def finish(ticket: Chan(Bool)) -> IO(Bool):
  IO.join(Bool, ticket)
