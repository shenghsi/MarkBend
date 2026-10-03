import Base
import ../src/LiveParagraph.bend as App

def Driver.prepare() -> IO(Unit):
  import "./native_app_save_as.c"

def Driver.finish() -> IO(Unit):
  import "./native_app_save_as.c"

def main() -> IO(Unit):
  do IO<Unit>:
    Driver.prepare()
    App.main()
    Driver.finish()
