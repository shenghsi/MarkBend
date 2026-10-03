import Base
import ../src/ByteRelease.bend as Release
import ../src/ByteBuffer.bend as Bytes
import ./ByteBufferCheck.bend as Buffer
import ./RecoveryRecordBench.bend as Fixture

def next(value: Release.Progress, more: Release.Queue -> IO(Unit), count: Nat,
  maximum: Nat, total: Nat) -> IO(Unit):
  match value:
    case Release.Complete{}:
      IO.print("byte_release slices=" ++ Nat.show(count) ++ " max_ms=" ++ Nat.show(maximum) ++
        " total_slice_ms=" ++ Nat.show(total))
    case Release.Pending{queue}:
      more(queue)

def run(fuel: Nat, queue: Release.Queue, +count: Nat, +maximum: Nat,
  +total: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit, 1, "Byte release did not complete")
    case 1n+remaining:
      do IO<Unit>:
        +start : Nat <- IO.now()
        result : Release.Progress = Release.step(8n, queue)
        +end : Nat <- IO.now()
        IO.sleep(1)
        next(result,
          q => run(remaining, q, 1n+count, Nat.max(maximum, Nat.sub(end, start)),
            Nat.add(total, Nat.sub(end, start))),
          1n+count, Nat.max(maximum, Nat.sub(end, start)),
          Nat.add(total, Nat.sub(end, start)))

def main() -> IO(Unit):
  buffer = Buffer.buffer(Bytes.from_bytes(Fixture.fixture(262144n, Nil{})))
  run(1024n, Release.begin(buffer), 0n, 0n, 0n)
