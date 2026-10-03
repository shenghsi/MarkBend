import Base
import ../src/ListReturn.bend as Return
import ./DirectCheck.bend as Check

def matches(edit: Return.Edit, start: Nat, end: Nat, text: String) -> Bool:
  match edit:
    case Return.Edit{actual_start, actual_end, actual_text}:
      Nat.is_eq(actual_start, start) && Nat.is_eq(actual_end, end) &&
        Check.source_equals(actual_text, text)

def fixture(source: String, start: Nat, end: Nat, expected_start: Nat,
  expected_end: Nat, text: String) -> IO(Unit):
  Check.check(matches(Return.plan(source, start, end), expected_start, expected_end, text))

def main() -> IO(Unit):
  do IO<Unit>:
    fixture("- text", 6n, 6n, 6n, 6n, "\n- ")
    fixture("* 中😀", 4n, 4n, 4n, 4n, "\n* ")
    fixture("+ \t text\r\n", 8n, 8n, 8n, 8n, "\r\n+ \t ")
    fixture("- ", 2n, 2n, 0n, 2n, "")
    fixture("* \t\r\n", 3n, 3n, 0n, 3n, "")
    fixture("+ \nnext", 2n, 2n, 0n, 2n, "")
    fixture("- text", 3n, 3n, 3n, 3n, "\n")
    fixture("- text", 2n, 6n, 2n, 6n, "\n")
    fixture("- text", 6n, 2n, 2n, 6n, "\n")
    fixture("-", 1n, 1n, 1n, 1n, "\n")
    fixture(" - text", 7n, 7n, 7n, 7n, "\n")
    fixture("1. text", 7n, 7n, 7n, 7n, "\n")
    fixture("before\r\n- 中😀", 12n, 12n, 12n, 12n, "\r\n- ")
    fixture("before\r\n- x\n", 11n, 11n, 11n, 11n, "\n- ")
    fixture("- x\r\n", 5n, 5n, 5n, 5n, "\r\n")
    fixture("```\n- text\n```", 10n, 10n, 10n, 10n, "\n")
    fixture("~~~\r\n- text", 11n, 11n, 11n, 11n, "\r\n")
    fixture("```\n```\n- x", 11n, 11n, 11n, 11n, "\n- ")
    fixture("- **中😀**", 8n, 8n, 8n, 8n, "\n- ")
    fixture("", 0n, 0n, 0n, 0n, "\n")
    IO.print("List Return source ranges, prefixes, line endings, and fence checks passed")
