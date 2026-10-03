import Base
import ./ReturnCommandCheck.bend as Command

def main() -> IO(Unit):
  do IO<Unit>:
    Command.fixture("+ \t x", 5n, 5n, 5n, 5n, "+ \t x\n+ \t ", 10n)
    Command.fixture("* \t\r\n", 3n, 3n, 3n, 3n, "\r\n", 0n)
    Command.fixture("- text", 3n, 3n, 3n, 3n, "- t\next", 4n)
    Command.fixture("```\n- x\n```", 7n, 7n, 7n, 7n, "```\n- x\n\n```", 8n)
    Command.fixture("~~~\r\n- x", 8n, 8n, 8n, 8n, "~~~\r\n- x\r\n", 10n)
    Command.fixture("- **a**", 3n, 3n, 7n, 7n, "- **a**\n- ", 10n)
    IO.print("Return command exact spacing, empty CRLF, middle, fences, and hidden marks passed")
