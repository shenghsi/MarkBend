import Base
import ./ReturnCommandBench.bend as Core

law output_matches:
  for +prefix: String
  for +suffix: String
  {Core.appended(prefix, suffix) == Core.appended_reference(prefix, suffix) : String}

def output_matches(prefix, suffix):
  {==}
