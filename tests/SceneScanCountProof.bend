import Base
import ../src/BlockScene.bend as Scene
import ../src/Document.bend as Document

law count_matches:
  for +source: String
  {Scene.scan_count(source) == Document.count_scalars(source, 0n) : Nat}

def count_matches(source):
  {==}
