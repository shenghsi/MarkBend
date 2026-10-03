import Base

# Include a BOM, CRLF, NUL, an emoji, and invalid UTF-8. The saved form is bytes.
def fixture() -> List<&2, U32>:
  [239, 187, 191, 35, 32, 65, 13, 10, 0, 240, 159, 152, 128, 255, 195, 40]

def equal(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xs} Con{y, ys}:
      U32.is_eq(x, y) && equal(xs, ys)
    case _ _:
      False{}

def checked(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("File byte preservation check passed")
    case False{}:
      IO.die(Unit, 1, "File effects changed saved bytes")

def consume(result: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  rest: File -> List<&2, U32> -> IO(Unit)) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        bytes : List<&2, U32> <- IO.pass(List<&2, U32>, value)
        rest(file, bytes)

# Read beyond EOF as well. Empty reads must not insert or repeat bytes.
def read_chunks(fuel: Nat, file: File, bytes: List<&2, U32>, size: U32) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        File.close(file)
        checked(equal(bytes, fixture()))
    case 1n+p:
      +chunk_size = size
      do IO<Unit>:
        result : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, chunk_size)
        consume(result, handle => chunk =>
          read_chunks(p, handle, List.append(&2, U32, bytes, chunk), chunk_size))

def read(path: String, size: U32) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "r"))
    read_chunks(32n, file, Nil{}, size)

def write_done(+path: String, result: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match result:
    case (file, value):
      do IO<Unit>:
        File.close(file)
        IO.pass(Unit, value)
        read(path, 1)
        read(path, 3)
        read(path, 4096)

def run(+path: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(file, fixture())
    write_done(path, result)

def main() -> IO(Unit):
  do IO<Unit>:
    path : String <- IO.try(String, IO.get_env("MARKBEND_FILE_CHECK_PATH"))
    run(path)
