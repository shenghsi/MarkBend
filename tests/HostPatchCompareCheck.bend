import Base
import ../src/BlockScene.bend as Scene
import ./HostPatchCheck.bend as Patch
import ./DirectCheck.bend as Check
import ./TextCompareOwnershipCheck.bend as Dynamic

def chunk(id: Nat, fresh: Bool, text: String, style: U32) -> Scene.HostChunk:
  Scene.HostChunk{id, fresh, [Scene.Run{text, style}]}

def shared(+items: List<&2, Scene.HostChunk>) -> Bool:
  Patch.same(items, items)

def main() -> IO(Unit):
  do IO<Unit>:
    Check.check(Patch.same(Nil{}, Nil{}))
    Check.check(Bool.not(Patch.same(Nil{}, [chunk(1n, True{}, "a", 0)])))
    Check.check(Bool.not(Patch.same([chunk(1n, True{}, "a", 0)], Nil{})))
    Check.check(Bool.not(Patch.same([chunk(1n, True{}, "a", 0)], [chunk(2n, True{}, "a", 0)])))
    Check.check(Bool.not(Patch.same([chunk(1n, True{}, "a", 0)], [chunk(1n, True{}, "b", 0)])))
    Check.check(Bool.not(Patch.same([chunk(1n, True{}, "a", 0)], [chunk(1n, True{}, "a", 1)])))
    Check.check(Patch.same([chunk(1n, True{}, "中文😀é", 0)], [chunk(1n, False{}, "中文😀é", 0)]))
    Check.check(shared([chunk(1n, True{}, Dynamic.make(129n, '中', "😀"), 0)]))
    Check.check(Bool.not(Patch.same(
      [chunk(1n, True{}, "a", 0), chunk(2n, True{}, "b", 0)],
      [chunk(1n, False{}, "a", 0), chunk(3n, False{}, "b", 0)])))
    Check.check(Bool.not(Patch.same(
      [chunk(1n, True{}, "a", 0), chunk(2n, True{}, Dynamic.make(129n, '中', "😀"), 0)],
      [chunk(3n, False{}, "a", 0), chunk(2n, False{}, Dynamic.make(129n, '中', "😀"), 0)])))
    Check.check(Bool.not(Patch.same_loop(
      [chunk(1n, True{}, Dynamic.make(129n, '中', "😀"), 0)],
      [chunk(1n, False{}, Dynamic.make(129n, '中', "😀"), 0)], False{})))
    IO.print("Host patch comparison paths passed")
