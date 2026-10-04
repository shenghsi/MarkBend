import Base
import ../src/Document.bend as D
import ../src/DirectState.bend as State
import ./DirectCheck.bend as Check
import ./TextCompareOwnershipCheck.bend as Dynamic
import ./Utf8Check.bend as Text

def reconstructed(+source: String) -> Bool:
  Check.source_equals(State.document_source(D.parse(source)), source)

def shared(+text: String, +reversed: String) -> Bool:
  Text.text_equal(D.prepend_owned(text, reversed), D.prepend_owned(text, reversed), True{})

def result(kind: String) -> Bool:
  match kind:
    case "empty":
      reconstructed("")
    case "single":
      reconstructed(Dynamic.make(129n, '中', "😀\r\n"))
    case "multiple":
      reconstructed("# Heading\n\n**bold** and *italic*\n\n- item\n> quote\n```bend\n中文😀\n```\n")
    case "blanks":
      reconstructed("\n\r\n\n")
    case "crlf":
      reconstructed("# Heading\r\n\r\n中文😀\r\n- item\r\n")
    case "bom":
      reconstructed("﻿# Heading\n中文😀")
    case "nul":
      reconstructed("abc\0中文😀\n\n- x\0")
    case "combining":
      reconstructed("é ä\n\n**中😀**")
    case "long":
      reconstructed(Dynamic.make(65536n, '中', ""))
    case "shared":
      shared(Dynamic.make(129n, '中', "😀"), Dynamic.make(129n, 'a', "z"))
    case "empty-prepend":
      Text.text_equal(D.prepend_owned("", Dynamic.make(129n, 'a', "")), Dynamic.make(129n, 'a', ""), True{})
    case "tail":
      Text.text_equal(D.prepend_owned("中文😀", "abc"), "😀文中abc", True{})
    case _:
      False{}

def choose(args: List<String>) -> IO(Unit):
  match args:
    case program <> kind <> Nil{}:
      do IO<Unit>:
        Check.check(result(kind))
        IO.print("Document source ownership path passed")
    case _:
      IO.die(Unit, 1, "Supply a document source path")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args
    choose(args)
