import Base

# Retained suspension has no resume service yet. It never supplies a close choice.
def wait() -> IO(Unit):
  import "./input_suspend.c"
  import "./input_suspend.js"
