# Portability Contract

## Rule

The Bend document core must not contain operating-system branches. Platform code
implements the `LiveParagraph` effect boundary and returns the same Bend values.

## Current adapters

| Target | Input adapter | Status |
|---|---|---|
| macOS native | AppKit multiline editor with automatic preview | Implemented |
| Linux native | POSIX multiline terminal checkpoint | Implemented |
| JavaScript | Browser prompt checkpoint | Implemented |
| Windows native | None | Blocked by the Bend 2 native toolchain |

The Linux terminal adapter is a functional portability baseline. It is not the
final Linux interface. A later GTK or Wayland adapter must keep the same effect
contract.

## Shared effect contract

- `LiveParagraph.open` creates one affine host session.
- `LiveParagraph.next` returns Change, Undo, Redo, or Close.
- `LiveParagraph.set` displays a state calculated by Bend.
- `LiveParagraph.set` also clears the prior preview. `LiveParagraph.append` adds
  one plain or bold text run. Bend sends all runs before the next input checkpoint.
- `LiveParagraph.close` releases the host session exactly once.

The host may own temporary IME composition. Bend owns applied text, undo, redo,
Markdown meaning, and saved document bytes.

## Platform checks

Every change to the host boundary must pass:

1. `bend PROOF.bend`
2. A native build on macOS.
3. A native build on Linux CI.
4. A JavaScript build.

On macOS, `clang -fsyntax-only tests/linux_host_syntax.c` checks the real POSIX
adapter against a minimal Bend runtime declaration surface. This is an early
check only. It does not replace the Linux CI build.

`.github/workflows/portability.yml` performs complete native Bend builds on
macOS and Ubuntu. A pull request must pass both jobs before merge.

Run `sh tests/check.sh` for the complete local batch. This is also the CI entry
point. Style codes are 0 for plain, 1 for strong, 2 for emphasis, and 3 for code.

An adapter must return an explicit error or documented fallback. It must not
silently discard input.
