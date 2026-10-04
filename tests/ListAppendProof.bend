import Base
import ../src/ListAppend.bend as Append

law reversed_accumulator:
  for -A: Data
  for +left: List<&2, A>
  for +acc: List<&2, A>
  for +right: List<&2, A>
  {Append.prepend(&2, A, List.reverse.go(&2, A, left, acc), right) ==
    Append.prepend(&2, A, acc, List.append(&2, A, left, right)) : List<&2, A>}

def reversed_accumulator(A, left, acc, right):
  match left:
    case Nil{}:
      {==}
    case head <> rest:
      reversed_accumulator(A, rest, head <> acc, right)

law output_matches:
  for -A: Data
  for +left: List<&2, A>
  for +right: List<&2, A>
  {Append.append(&2, A, left, right) == List.append(&2, A, left, right) : List<&2, A>}

def output_matches(A, left, right):
  reversed_accumulator(A, left, Nil{}, right)
