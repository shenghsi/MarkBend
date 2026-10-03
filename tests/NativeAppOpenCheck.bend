import Base
import ../src/LiveParagraph.bend as App

def Driver.prepare() -> IO(Unit):
  import "./native_app_open.c"

def Driver.finish() -> IO(Unit):
  import "./native_app_open.c"

def main() -> IO(Unit):
  do IO<Unit>:
    Driver.prepare()
    App.main()
    Driver.finish()
