import Base
import ../src/ByteRelease.bend as Release
import ../src/ByteBuffer.bend as Bytes
import ./ByteBufferCheck.bend as Buffer
import ./RecoveryRecordBench.bend as Fixture
import ../src/SaveState.bend as Save
import ./DirectCheck.bend as Check

def drained(fuel: Nat, value: Release.Progress) -> Bool:
  match fuel value:
    case _ Release.Complete{}:
      True{}
    case 0n _:
      False{}
    case 1n+remaining Release.Pending{queue}:
      drained(remaining, Release.step(8n, queue))

def pending(value: Release.Progress) -> Bool:
  match value:
    case Release.Pending{queue}:
      True{}
    case _:
      False{}

def main() -> IO(Unit):
  +bytes = Fixture.fixture(262144n, Nil{})
  +buffer = Buffer.buffer(Bytes.from_bytes(bytes))
  do IO<Unit>:
    Check.check(pending(Release.step(0n, Release.begin(buffer))))
    Check.check(drained(1024n, Release.step(8n, Release.begin(buffer))))
    Check.check(Bytes.valid(buffer))
    Check.check(Save.bytes_equal(Bytes.materialize(buffer), bytes))
    Check.check(drained(1n, Release.step(8n, Release.begin(Buffer.buffer(Bytes.from_bytes([]))))))
    IO.print("Byte release slices and retained snapshots check passed")
