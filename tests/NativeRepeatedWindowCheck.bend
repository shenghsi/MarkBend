import Base
import ./NativeReleaseCheck.bend as Native

def main() -> IO(Unit):
  do IO<Unit>:
    Native.run(1)
    Native.run(0)
    IO.print("Repeated native window input and release check passed")
