import Base
import ../src/IndexedReturn.bend as Indexed
import ../src/Blocks.bend as Blocks
import ./TextCompareOwnershipCheck.bend as Dynamic
import ./Utf8Check.bend as Text
import ./DirectCheck.bend as Check

def same(left: List<&2, String>, right: List<&2, String>, ok: Bool) -> Bool:
  match left right ok:
    case _ _ False{}:
      False{}
    case Nil{} Nil{} True{}:
      True{}
    case line <> rest other <> tail True{}:
      same(rest, tail, Text.text_equal(line, other, True{}))
    case _ _ _:
      False{}

def verify(+source: String, +expected: List<&2, String>) -> IO(Unit):
  do IO<Unit>:
    Check.check(same(Indexed.owned_lines(source), expected, True{}))
    Check.check(same(Blocks.lines(source), expected, True{}))

def path(kind: String) -> IO(Unit):
  match kind:
    case "empty":
      verify("", Nil{})
    case "newline":
      verify("\n", ["\n"])
    case "unicode":
      verify("中😀\nlast", ["中😀\n", "last"])
    case "crlf":
      verify("中😀\r\n\nlast\r\n", ["中😀\r\n", "\n", "last\r\n"])
    case "bom":
      verify("﻿# H\n", ["﻿# H\n"])
    case "nul":
      verify("a\0b\n\0", ["a\0b\n", "\0"])
    case "combining":
      verify("é ä\n", ["é ä\n"])
    case "shared":
      +source = Dynamic.make(129n, '中', "😀")
      verify(source, [source])
    case "long":
      verify(Dynamic.make(65536n, '中', ""), [Dynamic.make(65536n, '中', "")])
    case _:
      IO.die(Unit, 1, "Supply an indexed line ownership path")

def choose(args: List<String>) -> IO(Unit):
  match args:
    case program <> kind <> Nil{}:
      do IO<Unit>:
        path(kind)
        IO.print("Indexed line ownership path passed")
    case _:
      IO.die(Unit, 1, "Supply an indexed line ownership path")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args
    choose(args)
