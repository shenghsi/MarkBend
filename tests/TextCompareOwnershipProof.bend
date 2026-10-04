import Base
import ./Utf8Check.bend as Text

law output_matches:
  for +left: String
  for +right: String
  for +ok: Bool
  {Text.text_equal(left, right, ok) == Text.text_equal_loop(left, right, ok) : Bool}

def output_matches(left, right, ok):
  {==}
