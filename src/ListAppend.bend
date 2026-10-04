import Base

def prepend(a, -A: Kind(a), reversed: List<a, A>, right: List<a, A>) -> List<a, A>:
  match reversed:
    case Nil{}:
      right
    case head <> rest:
      prepend(a, A, rest, head <> right)

def append(a, -A: Kind(a), left: List<a, A>, right: List<a, A>) -> List<a, A>:
  prepend(a, A, List.reverse(a, A, left), right)
