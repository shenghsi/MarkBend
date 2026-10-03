import Base
import ./StoredEditor.bend as Editor
import ./SaveState.bend as Save

type Outcome is Data:
  Opened{session: Editor.Session}
  InvalidUtf8{bytes: List<&2, U32>}
  TooLarge{prefix: List<&2, U32>}
  ReadFailed{code: U32, message: String}

type ReadState is Data:
  ReadState{reversed: List<&2, U32>, count: Nat}

type ReadStep is Data:
  More{state: ReadState}
  Finished{result: Outcome}

def fits(fuel: Nat, bytes: List<&2, U32>) -> Bool:
  match fuel bytes:
    case _ Nil{}:
      True{}
    case 0n _ <> _:
      False{}
    case 1n+remaining _ <> rest:
      fits(remaining, rest)

def loaded(value: Maybe<&2, Editor.Session>, bytes: List<&2, U32>) -> Outcome:
  match value:
    case Some{session}:
      Opened{session}
    case None{}:
      InvalidUtf8{bytes}

def bounded(ok: Bool, +bytes: List<&2, U32>) -> Outcome:
  match ok:
    case True{}:
      loaded(Editor.load(Save.open(bytes)), bytes)
    case False{}:
      TooLarge{bytes}

# Read at most the limit plus one byte. Never silently open a truncated file.
def decoded(value: Result<&1, &1, U32 & String, List<&2, U32>>) -> Outcome:
  match value:
    case Done{+bytes}:
      bounded(fits(8388608n, bytes), bytes)
    case Fail{(code, message)}:
      ReadFailed{code, message}

def accumulate(bytes: List<&2, U32>, reversed: List<&2, U32>, count: Nat) -> ReadState:
  match bytes:
    case Nil{}:
      ReadState{reversed, count}
    case byte <> rest:
      accumulate(rest, byte <> reversed, 1n+count)

def next_read(too_large: Bool, state: ReadState) -> ReadStep:
  match too_large state:
    case True{} ReadState{reversed, count}:
      Finished{TooLarge{List.reverse(&2, U32, reversed)}}
    case False{} state:
      More{state}

def accumulated(state: ReadState) -> ReadStep:
  match state:
    case ReadState{reversed, +count}:
      next_read(Nat.is_gt(count, 8388608n), ReadState{reversed, count})

# A positive short read is not EOF. Decode only after an empty read.
def advance(value: Result<&1, &1, U32 & String, List<&2, U32>>,
  state: ReadState) -> ReadStep:
  match value state:
    case Fail{(code, message)} _:
      Finished{ReadFailed{code, message}}
    case Done{Nil{}} ReadState{reversed, count}:
      Finished{decoded(Done{List.reverse(&2, U32, reversed)})}
    case Done{byte <> rest} ReadState{reversed, count}:
      accumulated(accumulate(rest, byte <> reversed, 1n+count))

def continue_read(step: ReadStep, file: File,
  more: File -> ReadState -> IO(Outcome)) -> IO(Outcome):
  match step:
    case Finished{result}:
      do IO<Outcome>:
        File.close(file)
        return result
    case More{state}:
      more(file, state)

def read_done(value: File & Result<&1, &1, U32 & String, List<&2, U32>>,
  state: ReadState, more: File -> ReadState -> IO(Outcome)) -> IO(Outcome):
  match value:
    case (file, result):
      continue_read(advance(result, state), file, more)

def read_loop(fuel: Nat, file: File, state: ReadState) -> IO(Outcome):
  match fuel state:
    case 0n _:
      do IO<Outcome>:
        File.close(file)
        return ReadFailed{1, "Document read limit reached before EOF"}
    case 1n+remaining ReadState{reversed, +count}:
      do IO<Outcome>:
        result : File & Result<&1, &1, U32 & String, List<&2, U32>> <-
          File.read_bytes(file, U32.from_nat(Nat.min(4096n, Nat.sub(8388609n, count))))
        read_done(result, ReadState{reversed, count},
          f => s => read_loop(remaining, f, s))

def opened(value: Result<&1, &1, U32 & String, File>) -> IO(Outcome):
  match value:
    case Fail{(code, message)}:
      IO.pure(Outcome, ReadFailed{code, message})
    case Done{file}:
      read_loop(8388610n, file, ReadState{Nil{}, 0n})

def read(path: String) -> IO(Outcome):
  do IO<Outcome>:
    file : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    opened(file)
