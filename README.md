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

`LiveParagraph.bend` opens a scrollable, multiline native paragraph checkpoint.
Enter inserts a newline. Apply returns the complete text to Bend. Undo and Redo
ask Bend to calculate and display another state. Close releases the affine host
handle. Bend records every applied state in its history.

On Linux, the same Bend program uses a multiline terminal checkpoint. Enter
replacement text and finish with `.apply` on its own line. Use `.undo`, `.redo`,
or `.close` as the first line for those commands. See
[PORTABILITY.md](PORTABILITY.md) for the platform contract.

The Bend core now includes the first direct-formatting projection. Active text
shows the Markdown source. Inactive text hides `**` tokens while the projection
keeps the exact source unchanged. Only paired strong marks hide. Unfinished
marks stay visible, and more than one strong span can project in one paragraph.
