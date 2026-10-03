import Base

# Read only the explicit startup recovery experiment settings. The capability
# flag belongs to the process host, not to an operating-system branch in Bend.
def read() -> IO(Result<&1, &1, U32 & String,
  Bool & (Maybe<List<&2, U32>> & Maybe<List<&2, U32>>)>):
  import "./recovery_config.c"
  import "./recovery_config.js"
