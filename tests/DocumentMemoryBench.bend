import Base
import ./DocumentBench.bend as B
import ../src/Document.bend as D

# Separate full parses from shared-tree edits when checking retained memory.
def repeat_open(fuel: Nat, +text: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        B.open_bench(text)
        repeat_open(rest, text)

def repeat_edit(fuel: Nat, +text: String, +position: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        B.edit_at(D.parse(text), position, "edit")
        repeat_edit(rest, text, position)

def run(args: List<String>, +text: String) -> IO(Unit):
  match args:
    case program <> "open" <> Nil{}:
      repeat_open(20n, text)
    case program <> "start" <> Nil{}:
      repeat_edit(20n, text, 2n)
    case program <> "middle" <> Nil{}:
      repeat_edit(20n, text, 524288n)
    case program <> "end" <> Nil{}:
      repeat_edit(20n, text, 1048573n)
    case program <> Nil{}:
      B.repeat(20n, text)
    case _:
      IO.die(Unit, 2, "Use no argument, open, start, middle, or end")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args, B.sample(1048576n))
