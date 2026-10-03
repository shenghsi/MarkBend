import Base
import ../src/DocumentOpen.bend as Open
import ./DirectCheck.bend as Check

# The exact-limit file starts with invalid UTF-8, so it reaches validation
# without constructing an 8-MiB text scene. The over-limit file is all zeroes.
def exact(value: Open.Outcome) -> IO(Unit):
  match value:
    case Open.InvalidUtf8{+bytes}:
      Check.check(Open.fits(8388608n, bytes) && Bool.not(Open.fits(8388607n, bytes)))
    case _:
      Check.check(False{})

def over(value: Open.Outcome) -> IO(Unit):
  match value:
    case Open.TooLarge{+prefix}:
      Check.check(Open.fits(8388609n, prefix) && Bool.not(Open.fits(8388608n, prefix)))
    case _:
      Check.check(False{})

def main() -> IO(Unit):
  do IO<Unit>:
    +path : String <- IO.try(String, IO.get_env("MARKBEND_OPEN_LIMIT_PATH"))
    first : Open.Outcome <- Open.read(path ++ "/exact")
    exact(first)
    second : Open.Outcome <- Open.read(path ++ "/over")
    over(second)
    IO.print("Real 8-MiB document opening limit check passed")
