import Base
import ../src/Document.bend as D

law output_matches:
  for +text: String
  for +reversed: String
  {D.prepend_owned(text, reversed) == D.prepend_text(text, reversed) : String}

def output_matches(text, reversed):
  {==}
