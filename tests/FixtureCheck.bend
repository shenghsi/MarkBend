import Base
import ../src/DirectState.bend as State
import ./DirectCheck.bend as Check

type Reference is Data:
  Reference{unit: String, repeats: Nat, tail: Nat, size: Nat}

# Keep a short, independent description instead of a full reference source.
def create(+size: Nat) -> Reference:
  Reference{"# Heading\n\nThis paragraph has **strong** text and *emphasis*.\n\n",
    Nat.div(size, 63n), Nat.mod(size, 63n), size}

def matching(same: Bool, next: Unit -> Maybe<&2, String>) -> Maybe<&2, String>:
  match same:
    case False{}:
      None{}
    case True{}:
      next(Unit{})

def remaining(expected: String, actual: String) -> Maybe<&2, String>:
  match expected actual:
    case SNil{} _:
      Some{actual}
    case SCon{a, rest_a} SCon{b, rest_b}:
      matching(Char.is_eq(a, b), unit => remaining(rest_a, rest_b))
    case _ _:
      None{}

def next_pattern(result: Maybe<&2, String>, next: String -> Maybe<&2, String>) -> Maybe<&2, String>:
  match result:
    case None{}:
      None{}
    case Some{rest}:
      next(rest)

def pattern_remaining(fuel: Nat, actual: String, +unit: String, tail: Nat) -> Maybe<&2, String>:
  match fuel:
    case 0n:
      remaining(String.take(unit, tail), actual)
    case 1n+rest:
      next_pattern(remaining(unit, actual), text => pattern_remaining(rest, text, unit, tail))

def suffix_matches(result: Maybe<&2, String>, count: Nat) -> Bool:
  match result:
    case None{}:
      False{}
    case Some{suffix}:
      Check.source_equals(suffix, String.repeat("X", count))

def source_matches(actual: String, reference: Reference, count: Nat) -> Bool:
  match reference:
    case Reference{unit, repeats, tail, size}:
      suffix_matches(pattern_remaining(repeats, actual, unit, tail), count)

def selection_matches(snapshot: State.Snapshot, +position: Nat) -> Bool:
  match snapshot:
    case State.Snapshot{a, b, document}:
      Nat.is_eq(a, position) && Nat.is_eq(b, position)

def snapshot_matches(+snapshot: State.Snapshot, +reference: Reference, +count: Nat) -> Bool:
  match reference:
    case Reference{unit, repeats, tail, size}:
      +length = Nat.add(size, count)
      source_matches(State.source(snapshot), reference, count) &&
        selection_matches(snapshot, length) &&
        Nat.is_eq(State.source_length(snapshot), length)

def self_check() -> IO(Unit):
  +unit = {"# Heading\n\nThis paragraph has **strong** text and *emphasis*.\n\n" : String}
  do IO<Unit>:
    Check.check(source_matches("# Heading\n\nX", create(11n), 1n))
    Check.check(Bool.not(source_matches("# Heading\n\nXX", create(11n), 1n)))
    Check.check(Bool.not(source_matches("# heading\n\nX", create(11n), 1n)))
    Check.check(Bool.not(source_matches("# Heading\nX", create(11n), 1n)))
    Check.check(source_matches("X", create(0n), 1n))
    Check.check(source_matches(unit ++ unit ++ "# HeXX", create(130n), 2n))
    Check.check(Bool.not(source_matches(unit ++ unit ++ "# heXX", create(130n), 2n)))
    Check.check(Bool.not(source_matches(unit ++ "wrong" ++ "# HeXX", create(130n), 2n)))
