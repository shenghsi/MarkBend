import Base
import ./DocumentFile.bend as Host
import ./InitialOpen.bend as Initial

def read(+requested: String) -> IO(Initial.Outcome):
  do IO<Initial.Outcome>:
    value : Result<&1, &1, U32 & String,
      List<&2, U32> & (List<&2, U32> & List<&2, U32>)> <- Host.read_raw(requested)
    return Initial.received(value, requested)
