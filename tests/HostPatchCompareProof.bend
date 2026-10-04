import Base
import ../src/BlockScene.bend as Scene
import ./HostPatchCheck.bend as Patch
import ./SessionViewCheck.bend as View

law loop_matches:
  for +a: List<&2, Scene.HostChunk>
  for +b: List<&2, Scene.HostChunk>
  for +ok: Bool
  {Patch.same_loop(a, b, ok) == (ok && Patch.same_reference(a, b)) : Bool}

def loop_matches(a, b, ok):
  match a b ok:
    case Nil{} Nil{} False{}:
      {==}
    case Nil{} head <> tail False{}:
      {==}
    case head <> rest Nil{} False{}:
      {==}
    case head <> rest other <> tail False{}:
      {==}
    case Nil{} Nil{} True{}:
      {==}
    case Scene.HostChunk{id, fresh, runs} <> rest Scene.HostChunk{other, flag, later} <> tail True{}:
      loop_matches(rest, tail, Nat.is_eq(id, other) && View.same_runs(runs, later))
    case Nil{} head <> tail True{}:
      {==}
    case head <> rest Nil{} True{}:
      {==}

law output_matches:
  for +a: List<&2, Scene.HostChunk>
  for +b: List<&2, Scene.HostChunk>
  {Patch.same(a, b) == Patch.same_reference(a, b) : Bool}

def output_matches(a, b):
  loop_matches(a, b, True{})
