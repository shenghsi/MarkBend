import Base
import ../src/ScalarText.bend as Scalar
import ./DirectCheck.bend as Check

def main() -> IO(Unit):
  do IO<Unit>:
    Check.check(String.eq(Scalar.from_chars(Scalar.to_chars("")), ""))
    Check.check(String.eq(Scalar.from_chars(Scalar.to_chars("x")), "x"))
    Check.check(String.eq(Scalar.from_chars(Scalar.to_chars("中文😀é\r\n\0")), "中文😀é\r\n\0"))
    Check.check(String.eq(Scalar.from_reversed(['b', 'a'], "tail"), "abtail"))
    Check.check(String.eq(Scalar.take_chars(['a', 'b'], 0n, Nil{}), ""))
    Check.check(String.eq(Scalar.take_chars(['a', 'b'], 1n, Nil{}), "a"))
    Check.check(String.eq(Scalar.take_chars(['a', 'b'], 3n, Nil{}), "ab"))
    IO.print("Scalar text conversion check passed")
