import Base
import ../src/Projection.bend as Projection
import ../src/Experiment.bend as E
import ../src/CursorMap.bend as Cursor
import ../src/ScalarText.bend as Scalar

law complete_mapping:
  for source: String
  for runs: List<&2, E.RenderRun>
  {Projection.mapping(source, runs) == Cursor.build(runs, Scalar.to_chars(source), 0n) : List<&2, Nat>}

def complete_mapping(source, runs):
  {==}
