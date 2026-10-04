import Base
import ../src/IndexedReturn.bend as Indexed
import ../src/Blocks.bend as Blocks

law output_matches:
  for +source: String
  {Indexed.owned_lines(source) == Blocks.lines(source) : List<&2, String>}

def output_matches(source):
  {==}
