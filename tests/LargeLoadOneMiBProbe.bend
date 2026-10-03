import Base
import ./LargeLoadProbe.bend as Probe

def main() -> IO(Unit):
  Probe.run(1048576n)
