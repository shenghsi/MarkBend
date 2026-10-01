# MarkBend

MarkBend is an experiment toward a native, direct-formatting Markdown editor
with a Bend document core.

Read [TARGET.md](TARGET.md) for the product target. The first experiment in
`Experiment.bend` tests a cursor buffer, direct strong-text projection, and
balanced parallel measurement.

## Run

```sh
export PATH="$HOME/.bend/bin:$PATH"
bend PROOF.bend
bend Experiment.bend
bend NativeParagraph.bend -o native-paragraph
./native-paragraph
bend LiveParagraph.bend -o live-paragraph
./live-paragraph
```

The proof command must report `All terms check.` The experiment reports the byte
counts on both sides of its cursor. The model also reconstructs the exact source
and maps source points when strong Markdown marks become visible or hidden.

`NativeParagraph.bend` is the first native boundary experiment. On macOS it
opens one native Unicode paragraph field with IME support. The native field owns
temporary composition only. Bend receives and commits the complete text.

On macOS, `LiveParagraph.bend` opens a scrollable multiline editor. Enter inserts
a newline. Committed text changes automatically update the Bend preview. The
editor stays open and keeps the cursor position. IME marked text is temporary;
the host sends a change after composition commits. Undo and Redo buttons ask
Bend to calculate another state. Close releases the affine host handle.

Command-Z and Command-Shift-Z use Bend Undo and Redo. Command-A, Command-C,
Command-X, and Command-V use native selection and clipboard actions. Paste inserts
plain text. History commands wait while IME marked text is active. The native
editor does not automatically replace quotes, dashes, spelling, or text snippets.

On Linux, the same Bend program uses a multiline terminal checkpoint. Enter
replacement text and finish with `.apply` on its own line. Use `.undo`, `.redo`,
or `.close` as the first line for those commands. See
[PORTABILITY.md](PORTABILITY.md) for the platform contract.

The Bend core now includes the first direct-formatting projection. Active text
shows the Markdown source. Inactive text hides `**` tokens while the projection
keeps the exact source unchanged. Only paired strong marks hide. Unfinished
marks stay visible, and more than one strong span can project in one paragraph.

Bend produces a list of `PlainRun` and `StrongRun` values. The host clears the
previous preview and draws every run in order. The macOS checkpoint uses native
font attributes. Linux uses ANSI bold. Both support multiple strong spans and
preserve Unicode and newlines. Unfinished marks remain visible.

The renderer supports `*italic*`, `**bold**`, and single-backtick inline code.
Code keeps emphasis marks literal. Escaped asterisks and backticks in plain text
are literal. macOS uses italic and monospace fonts. Linux uses ANSI italic and
inverse video for code. JavaScript stores each run's style.

Nested styles, escapes inside styled spans, multiple-backtick code delimiters,
underscore delimiters, and full CommonMark delimiter rules are not implemented.

Run the complete rendering batch:

```sh
sh tests/check.sh
```

This runs the Bend proof gate, native and JavaScript builds, the pure experiment,
and platform adapter tests. CI runs the same batch on macOS and Ubuntu.
