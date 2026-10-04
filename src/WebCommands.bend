import Base
import ./ListReturn.bend as Return
import ./TextPosition.bend as Position

# WebView positions count UTF-16 units in the exact source record.
def return_edit(+source: String, start: U32, end: U32) -> Return.Edit:
  Return.plan(source, Position.to_scalar(source, U32.to_nat(start)),
    Position.to_scalar(source, U32.to_nat(end)))
