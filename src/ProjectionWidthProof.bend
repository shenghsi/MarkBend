import Base
import ./Projection.bend as P
import ./CursorMap.bend as C
import ./Experiment.bend as E
import ./ScalarText.bend as Scalar
import ./ProjectionWidthLongProof.bend as Long
import ./ProjectionWidthShortProof.bend as Short

law chosen:
  for short: Bool
  for +visible: List<&2, Char>
  for +chars: List<&2, Char>
  for +offset: Nat
  for +plain: Bool
  {P.consume_width(visible, chars, offset, plain) == Long.width(C.consume_chosen(short, visible, chars, offset, plain)) : P.Width}

def chosen(short, visible, chars, offset, plain):
  match short:
    case True{}:
      Short.loop(visible, chars, offset, plain)
    case False{}:
      Long.loop(visible, chars, offset, Nil{}, plain)

law consume:
  for +visible: List<&2, Char>
  for +chars: List<&2, Char>
  for +offset: Nat
  for +plain: Bool
  {P.consume_width(visible, chars, offset, plain) == Long.width(C.consume(visible, chars, offset, plain)) : P.Width}

def consume(visible, chars, offset, plain):
  chosen(C.short_enough(visible, 128n), visible, chars, offset, plain)

law finish:
  for +run: E.RenderRun
  for +marks: Nat
  for +chunk: C.Chunk
  {P.width_finish(run, marks, Long.width(chunk)) == P.part_finish(run, marks, chunk) : P.Part}

def finish(run, marks, chunk):
  match chunk:
    case C.Chunk{positions, remaining, offset}:
      {==}

law part_step:
  for +run: E.RenderRun
  for +visible: List<&2, Char>
  for +chars: List<&2, Char>
  for +offset: Nat
  for +marks: Nat
  for +plain: Bool
  {P.width_finish(run, marks, P.consume_width(visible, chars, offset, plain)) == P.part_finish(run, marks, C.consume(visible, chars, offset, plain)) : P.Part}

def part_step(run, visible, chars, offset, marks, plain):
  Equal.trans(P.Part,
    P.width_finish(run, marks, P.consume_width(visible, chars, offset, plain)),
    P.width_finish(run, marks, Long.width(C.consume(visible, chars, offset, plain))),
    P.part_finish(run, marks, C.consume(visible, chars, offset, plain)),
    Equal.cong(P.Width, P.Part, w => P.width_finish(run, marks, w),
      P.consume_width(visible, chars, offset, plain),
      Long.width(C.consume(visible, chars, offset, plain)),
      consume(visible, chars, offset, plain)),
    finish(run, marks, C.consume(visible, chars, offset, plain)))

def reference(run: E.RenderRun, chars: List<&2, Char>) -> P.Part:
  match run:
    case E.PlainRun{+text}:
      P.part_finish(E.PlainRun{text}, 0n, C.consume(Scalar.to_chars(text), chars, 0n, True{}))
    case E.StrongRun{+text}:
      P.part_finish(E.StrongRun{text}, 2n, C.consume(Scalar.to_chars(text), C.skip(chars, 2n), 2n, False{}))
    case E.EmphasisRun{+text}:
      P.part_finish(E.EmphasisRun{text}, 1n, C.consume(Scalar.to_chars(text), C.skip(chars, 1n), 1n, False{}))
    case E.CodeRun{+text}:
      P.part_finish(E.CodeRun{text}, 1n, C.consume(Scalar.to_chars(text), C.skip(chars, 1n), 1n, False{}))

law part:
  for +run: E.RenderRun
  for +chars: List<&2, Char>
  {P.part(run, chars) == reference(run, chars) : P.Part}

def part(run, chars):
  match run:
    case E.PlainRun{+text}:
      part_step(E.PlainRun{text}, Scalar.to_chars(text), chars, 0n, 0n, True{})
    case E.StrongRun{+text}:
      part_step(E.StrongRun{text}, Scalar.to_chars(text), C.skip(chars, 2n), 2n, 2n, False{})
    case E.EmphasisRun{+text}:
      part_step(E.EmphasisRun{text}, Scalar.to_chars(text), C.skip(chars, 1n), 1n, 1n, False{})
    case E.CodeRun{+text}:
      part_step(E.CodeRun{text}, Scalar.to_chars(text), C.skip(chars, 1n), 1n, 1n, False{})
