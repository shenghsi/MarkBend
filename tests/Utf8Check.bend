import Base
import ../src/Utf8.bend as Utf8
import ../src/SaveState.bend as Save
import ./DirectCheck.bend as Check

def text_equal_loop(left: String, right: String, ok: Bool) -> Bool:
  match left right ok:
    case SNil{} SNil{} True{}:
      True{}
    case SCon{a, rest_a} SCon{b, rest_b} True{}:
      text_equal_loop(rest_a, rest_b, Char.is_eq(a, b))
    case _ _ _:
      False{}

type TextCompareWork is Data:
  TextCompareWork{right: String, result: Bool}

def text_compare_work(left: String, +right: String, ok: Bool) -> TextCompareWork:
  TextCompareWork{right, text_equal_loop(left, right, ok)}

def text_compare_result(work: TextCompareWork) -> Bool:
  match work:
    case TextCompareWork{right, result}:
      result

def text_equal(left: String, right: String, ok: Bool) -> Bool:
  text_compare_result(text_compare_work(left, right, ok))

def decoded(value: Maybe<&2, String>, expected: String) -> Bool:
  match value:
    case Some{text}:
      text_equal(text, expected, True{})
    case None{}:
      False{}

def encoded(value: Maybe<&2, List<&2, U32>>, expected: List<&2, U32>) -> Bool:
  match value:
    case Some{bytes}:
      Save.bytes_equal(bytes, expected)
    case None{}:
      False{}

def rejected(value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def invalid(cases: List<&2, List<&2, U32>>, ok: Bool) -> Bool:
  match cases:
    case Nil{}:
      ok
    case bytes <> rest:
      invalid(rest, ok && rejected(Utf8.decode(bytes)))

def include(valid: Bool, code: U32, text: String) -> String:
  match valid:
    case True{}:
      SCon{Chr{code}, text}
    case False{}:
      text

def scalars(count: Nat, +code: U32, text: String) -> String:
  match count:
    case 0n:
      text
    case 1n+rest:
      scalars(rest, U32.add(code, 1),
        include(Bool.not(Utf8.between(code, 55296, 57343)), code, text))

def byte_count(bytes: List<&2, U32>, count: U32) -> U32:
  match bytes:
    case Nil{}:
      count
    case head <> rest:
      byte_count(rest, U32.add(count, 1))

def roundtrip(value: Maybe<&2, List<&2, U32>>, expected: String) -> Bool:
  match value:
    case Some{+bytes}:
      U32.is_eq(byte_count(bytes, 0), 4382592) && decoded(Utf8.decode(bytes), expected)
    case None{}:
      False{}

def rejected_text(value: Maybe<&2, List<&2, U32>>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def main() -> IO(Unit):
  +all = scalars(U32.to_nat(1114112), 0, "")
  do IO<Unit>:
    Check.check(decoded(Utf8.decode(Nil{}), ""))
    Check.check(encoded(Utf8.encode(""), Nil{}))
    Check.check(decoded(Utf8.decode([0, 13, 10, 239, 187, 191]), "\0\r\n\u{feff}"))
    Check.check(encoded(Utf8.encode("\0\r\n\u{feff}"), [0, 13, 10, 239, 187, 191]))
    Check.check(decoded(Utf8.decode([228, 184, 173, 230, 150, 135, 240, 159, 152, 128]), "中文😀"))
    Check.check(encoded(Utf8.encode("中文😀"), [228, 184, 173, 230, 150, 135, 240, 159, 152, 128]))
    Check.check(encoded(Utf8.encode("\u{7f}\u{80}\u{7ff}\u{800}\u{d7ff}\u{e000}\u{ffff}\u{10000}\u{10ffff}"),
      [127, 194, 128, 223, 191, 224, 160, 128, 237, 159, 191, 238, 128, 128,
       239, 191, 191, 240, 144, 128, 128, 244, 143, 191, 191]))
    Check.check(invalid([[128], [191], [192, 128], [193, 191], [194], [194, 127],
      [224, 128, 128], [224, 159, 191], [237, 160, 128], [237, 191, 191],
      [240, 128, 128, 128], [244, 144, 128, 128], [245, 128, 128, 128], [255],
      [256], [4294967295], [226, 130], [240, 159, 152], [65, 255], [226, 65, 128]], True{}))
    Check.check(Bool.not(Utf8.scalar(55296)))
    Check.check(Bool.not(Utf8.scalar(1114112)))
    Check.check(roundtrip(Utf8.encode(all), all))
    IO.print("Strict UTF-8 vectors and all Unicode scalar values check passed")
