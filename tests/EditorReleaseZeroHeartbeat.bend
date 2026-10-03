import Base
import ./EditorReleaseHeartbeat.bend as Heartbeat

def main() -> IO(Unit):
  Heartbeat.run(0)
