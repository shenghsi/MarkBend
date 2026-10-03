import Base
import ./NativeReleaseCheck.bend as Native

def main() -> IO(Unit):
  Native.run(0)
