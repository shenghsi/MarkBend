import Base

def chars_loop(text: String, reversed: List<&2, Char>) -> List<&2, Char>:
  match text:
    case SNil{}:
      List.reverse(&2, Char, reversed)
    case SCon{char, rest}:
      chars_loop(rest, char <> reversed)

def to_chars(text: String) -> List<&2, Char>:
  chars_loop(text, Nil{})

def from_reversed(chars: List<&2, Char>, acc: String) -> String:
  match chars:
    case Nil{}:
      acc
    case char <> rest:
      from_reversed(rest, SCon{char, acc})

def from_chars(chars: List<&2, Char>) -> String:
  from_reversed(List.reverse(&2, Char, chars), "")

def take_chars(chars: List<&2, Char>, count: Nat, reversed: List<&2, Char>) -> String:
  match chars count:
    case _ 0n:
      from_reversed(reversed, "")
    case Nil{} _:
      from_reversed(reversed, "")
    case char <> rest 1n+remaining:
      take_chars(rest, remaining, char <> reversed)
