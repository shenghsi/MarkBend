import Base

# Raw resolved path, opaque destination identity, and document bytes.
# The host checks a regular-file descriptor and closes it before returning.
def read_raw(path: String) -> IO(Result<&1, &1, U32 & String,
  List<&2, U32> & (List<&2, U32> & List<&2, U32>)>):
  import "./document_file.c"
  import "./document_file.js"
