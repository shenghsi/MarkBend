import Base
import ./DocumentFile.bend as Host
import ./ResolvedOpen.bend as Open

def read(+requested: String) -> IO(Open.Outcome):
  do IO<Open.Outcome>:
    value : Result<&1, &1, U32 & String,
      List<&2, U32> & (List<&2, U32> & List<&2, U32>)> <- Host.read_raw(requested)
    return Open.received(value, requested)
