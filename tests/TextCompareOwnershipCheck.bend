import Base
import ./Utf8Check.bend as Text
import ./DirectCheck.bend as Check
import ./SessionViewCheck.bend as Compare
import ../src/BlockScene.bend as Scene

def make(fuel: Nat, +char: Char, acc: String) -> String:
  match fuel:
    case 0n:
      acc
    case 1n+rest:
      make(rest, char, SCon{char, acc})

def shared(+text: String) -> Bool:
  Text.text_equal(text, text, True{})

def scene(left: List<&2, Scene.Run>, right: List<&2, Scene.Run>) -> Bool:
  Compare.same_scene(Scene.Scene{left, [0n]}, Scene.Scene{right, [0n]})

def result(kind: String) -> Bool:
  match kind:
    case "success":
      Text.text_equal(make(129n, '中', "😀"), make(129n, '中', "😀"), True{})
    case "first":
      Bool.not(Text.text_equal(make(129n, 'a', ""), make(129n, 'b', ""), True{}))
    case "last":
      Bool.not(Text.text_equal(make(129n, 'a', "b"), make(129n, 'a', "c"), True{}))
    case "left-short":
      Bool.not(Text.text_equal(make(128n, 'a', ""), make(129n, 'a', ""), True{}))
    case "right-short":
      Bool.not(Text.text_equal(make(129n, 'a', ""), make(128n, 'a', ""), True{}))
    case "empty-left":
      Bool.not(Text.text_equal("", make(129n, 'a', ""), True{}))
    case "empty-right":
      Bool.not(Text.text_equal(make(129n, 'a', ""), "", True{}))
    case "false":
      Bool.not(Text.text_equal(make(129n, 'a', ""), make(129n, 'a', ""), False{}))
    case "shared":
      shared(make(129n, '中', "😀"))
    case "style":
      Bool.not(scene([Scene.Run{make(129n, 'a', ""), 0}], [Scene.Run{make(129n, 'a', ""), 1}]))
    case "text":
      Bool.not(scene([Scene.Run{make(129n, 'a', ""), 0}], [Scene.Run{make(129n, 'b', ""), 0}]))
    case "runs-left":
      Bool.not(scene([Scene.Run{make(129n, 'a', ""), 0}, Scene.Run{make(129n, 'b', ""), 1}],
        [Scene.Run{make(129n, 'a', ""), 0}]))
    case "runs-right":
      Bool.not(scene([Scene.Run{make(129n, 'a', ""), 0}],
        [Scene.Run{make(129n, 'a', ""), 0}, Scene.Run{make(129n, 'b', ""), 1}]))
    case _:
      False{}

def choose(args: List<String>) -> IO(Unit):
  match args:
    case program <> kind <> Nil{}:
      do IO<Unit>:
        Check.check(result(kind))
        IO.print("Comparison ownership path passed")
    case _:
      IO.die(Unit, 1, "Supply a comparison path")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args
    choose(args)
