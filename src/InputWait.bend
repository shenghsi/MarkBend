import Base
import ./AppInput.bend as Input

# Isolated native experiment. The host supplies borrowed private stream-socket
# descriptors. The prototype accepts stream sockets of any address family;
# the automatic fixtures use private Unix sockets. 0 means an exact fresh wake;
# all other values mean unavailable.
# This does not keep an unavailable result alive or authorize Save/Discard.
def wait_raw(control: U32, notice: U32) -> IO(U32):
  import "./input_wait.c"
  import "./input_wait.js"

def decoded(code: U32) -> Input.Wake:
  match code:
    case 0:
      Input.Resumed{}
    case _:
      Input.Unavailable{}

def wait(control: U32, notice: U32) -> IO(Input.Wake):
  do IO<Input.Wake>:
    code : U32 <- wait_raw(control, notice)
    return decoded(code)
