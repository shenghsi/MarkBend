import Base
import ../src/Projection.bend as Projection
import ../src/CursorMap.bend as Cursor
import ../src/ScalarText.bend as Scalar
import ../src/Experiment.bend as E
import ./ReturnCommandCheck.bend as Fixture
import ./DirectCheck.bend as Check
import ./Utf8Check.bend as Text
import ./ReturnCommandBench.bend as Core

# Keep the old position-producing implementation as the reference.
def reference(run: E.RenderRun, chars: List<&2, Char>) -> Projection.Part:
  match run:
    case E.PlainRun{+text}:
      Projection.part_finish(E.PlainRun{text}, 0n,
        Cursor.consume(Scalar.to_chars(text), chars, 0n, True{}))
    case E.StrongRun{+text}:
      Projection.part_finish(E.StrongRun{text}, 2n,
        Cursor.consume(Scalar.to_chars(text), Cursor.skip(chars, 2n), 2n, False{}))
    case E.EmphasisRun{+text}:
      Projection.part_finish(E.EmphasisRun{text}, 1n,
        Cursor.consume(Scalar.to_chars(text), Cursor.skip(chars, 1n), 1n, False{}))
    case E.CodeRun{+text}:
      Projection.part_finish(E.CodeRun{text}, 1n,
        Cursor.consume(Scalar.to_chars(text), Cursor.skip(chars, 1n), 1n, False{}))

def characters(a: List<&2, Char>, b: List<&2, Char>, ok: Bool) -> Bool:
  match a b ok:
    case _ _ False{}:
      False{}
    case Nil{} Nil{} True{}:
      True{}
    case x <> rest y <> later True{}:
      characters(rest, later, Char.is_eq(x, y))
    case _ _ _:
      False{}

def same_run(a: E.RenderRun, b: E.RenderRun) -> Bool:
  match a b:
    case E.PlainRun{x} E.PlainRun{y}:
      Text.text_equal(x, y, True{})
    case E.StrongRun{x} E.StrongRun{y}:
      Text.text_equal(x, y, True{})
    case E.EmphasisRun{x} E.EmphasisRun{y}:
      Text.text_equal(x, y, True{})
    case E.CodeRun{x} E.CodeRun{y}:
      Text.text_equal(x, y, True{})
    case _ _:
      False{}

def same(a: Projection.Part, b: Projection.Part) -> Bool:
  match a b:
    case Projection.Part{run, width, rest} Projection.Part{other, count, later}:
      same_run(run, other) && Nat.is_eq(width, count) && characters(rest, later, True{})

def fixture(+run: E.RenderRun, +source: String) -> IO(Unit):
  Check.check(same(Projection.part(run, Scalar.to_chars(source)),
    reference(run, Scalar.to_chars(source))))

def styles(+text: String) -> IO(Unit):
  do IO<Unit>:
    fixture(E.PlainRun{text}, Core.appended(text, "tail"))
    fixture(E.StrongRun{text}, "**" ++ Core.appended(text, "**tail"))
    fixture(E.EmphasisRun{text}, "*" ++ Core.appended(text, "*tail"))
    fixture(E.CodeRun{text}, "`" ++ Core.appended(text, "`tail"))
    fixture(E.PlainRun{text}, "")
    fixture(E.StrongRun{text}, "*")
    fixture(E.EmphasisRun{text}, "*")
    fixture(E.CodeRun{text}, "`x")

def main() -> IO(Unit):
  do IO<Unit>:
    styles("")
    styles("中😀é*`")
    styles(Fixture.repeated(127n, ""))
    styles(Fixture.repeated(128n, ""))
    styles(Fixture.repeated(129n, ""))
    styles(Fixture.repeated(65536n, ""))
    fixture(E.PlainRun{"*`x"}, "\\*\\`xtail")
    fixture(E.PlainRun{"*"}, "\\*")
    fixture(E.PlainRun{"`"}, "\\`")
    fixture(E.PlainRun{"*"}, "\\")
    fixture(E.PlainRun{"a"}, "😀tail")
    fixture(E.PlainRun{"*x"}, "\\*tail")
    fixture(E.StrongRun{"😀"}, "**x**tail")
    fixture(E.EmphasisRun{"ab"}, "*x")
    fixture(E.CodeRun{"*`"}, "`\\*\\`tail")
    fixture(E.PlainRun{Fixture.repeated(129n, "")}, Fixture.repeated(127n, ""))
    fixture(E.PlainRun{Core.appended(Fixture.repeated(65535n, ""), "*")},
      Core.appended(Fixture.repeated(65535n, ""), "\\*tail"))
    IO.print("Projection Part reference: styles, width, complete remainder, escapes, Unicode, exhaustion, and lengths passed")
