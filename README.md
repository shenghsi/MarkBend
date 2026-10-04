# MarkBend

The active app uses CodeMirror 6 in a Tauri desktop WebView. Source files are in
`src/web/` and `src/desktop/`. CodeMirror owns input and history. Bend supplies
edit commands. The native Bend adapters below remain reference experiments.

Run the new app from the project root:

```sh
npm ci
npm run desktop
```

The build needs Node.js, Rust, Tauri's platform tools, and Bend on PATH.
`BEND_BIN=/absolute/path/to/bend` selects a Bend compiler. This project currently
checks Bend 2.0.34. Build the app with `npm run desktop:build`.

The source record retains UTF-8 text, its BOM, and mixed line endings. Save
checks the file baseline and uses a temporary file before replacement. Save As
requires a new destination. The new path still needs IME, recovery, and Windows
and Linux checks before release. The old adapter's results do not cover it.
The app has live preview with source reveal, Markdown and code highlighting,
MathJax formulas, Mermaid diagrams, tables, and isolated HTML. Select a preview
widget to edit its source. The Source button changes the display and retains
history. Theme offers System, Light, and Dark display preferences and retains
the editor state and Undo history. MathJax and its fonts are included in the app.
Formula rendering does not change the source or require a server. MathJax
currently loads the base, AMS, and newcommand TeX packages. Markdown math uses
dollar delimiters. Return continues nested lists, task items, and quotes. Empty
nested items exit one level. These commands use the document's Undo history.
Select a table cell to edit its
single-line Markdown text. Tab moves between cells; Enter or Escape ends the
cell edit. Table source reveals the complete table. Cell edits use the same
Undo history as the document. Table buttons insert or delete rows and columns
and change column alignment. The header and last column cannot be deleted.
Structure commands for tables inside lists or quotes stay disabled. Multiline
cells remain open. Omitted cells in short rows can be edited. Selecting one
leaves source unchanged; first input adds its slots in one Undo step.
HTML preview permits local styles and data images; it blocks
scripts and external resources.
Recovery keeps exact source copies in the app-data folder after a short input
delay. The Recovery panel offers inactive-session copies. Restore opens an
untitled unsaved document and keeps both the copy and the original file. A
checkpoint failure shows Retry recovery. Native crash/restart checks remain
open; input before acknowledgment is not guaranteed to survive an interruption.

Find opens search and replace. Use Command-F on macOS or Control-F on Windows
and Linux. Search reads Markdown source, including hidden formulas and tables.
The panel supports case, whole-word, and regular-expression options. Replace
All uses one Undo step. Outline shows document headings and navigates to their
source positions. Both features work in preview and Source mode.
The final disk comparison and replacement are separate operations. An external
writer can still change the file between them. Full conflict handling remains
a release requirement. Window Close checks unsaved text; application Quit still
needs its own check.

## Earlier native experiments

Startup reads only `MARKBEND_OPEN_PATH` through a separate host effect. A missing
setting opens the demo. An empty setting attempts file opening and reports an
error. Native path bytes must be valid UTF-8. Bun and Node read the runtime's
environment string without using `bun:ffi` for this setting. Node file opening
still depends on Bend's file effects and is not verified.

MarkBend is an experiment toward a native, direct-formatting Markdown editor
with a Bend document core.

Application source files are in `src/`. Tests are in `tests/`. Project documents
stay at the root. `LAWS.bend` and `PROOF.bend` also stay at the root so that
`bend PROOF.bend` remains the proof command. Run build commands from the root.

Read [TARGET.md](TARGET.md) for the product target. The first experiment in
`src/Experiment.bend` tests a cursor buffer, direct strong-text projection, and
balanced parallel measurement.

## Run

```sh
export PATH="$HOME/.bend/bin:$PATH"
bend PROOF.bend
bend src/Experiment.bend
bend src/NativeParagraph.bend -o native-paragraph
./native-paragraph
bend src/LiveParagraph.bend -o live-paragraph
./live-paragraph
```

To open an existing UTF-8 file in the live app:

```sh
MARKBEND_OPEN_PATH=/absolute/path/document.md ./live-paragraph
```

Opening is read-only. The current file-size limit is 8 MiB. Invalid UTF-8 and
read failures stop opening before an editor is created. File dialogs and disk
save commands are still incomplete.

The proof command must report `ALL PROOFS CHECK`. The experiment reports the byte
counts on both sides of its cursor. The model also reconstructs the exact source
and maps source points when strong Markdown marks become visible or hidden.

`src/NativeParagraph.bend` is the first native boundary experiment. On macOS it
opens one native Unicode paragraph field with IME support. The native field owns
temporary composition only. Bend receives and commits the complete text.

On macOS, `src/LiveParagraph.bend` opens a formatted multiline edit surface and a
source field. Enter inserts a newline. At the end of a top-level unordered
item, it continues the same marker and spacing. In an empty item, it removes
the prefix and keeps the existing line ending. The active text run shows its exact
Markdown source. Other runs keep their formatting. Bend maps native selections
back to source positions and applies replacements to the source. IME marked text
is temporary; the host sends a change after composition commits. Undo and Redo
restore the Bend source and its formatted-surface selection. Close releases the
affine host handle.

The live app now uses `StoredEditor` for persistent UTF-8 text storage and edit
history. Native edits and full source replacements update the byte snapshot
before presentation. Undo and redo retain the saved baseline and any pending
save snapshot. File startup now uses the resolved reader. An explicit recovery
experiment uses `MARKBEND_STARTUP_RECOVERY_HOST` and
`MARKBEND_STARTUP_RECOVERY_ROOT`. Both must be set together, or both absent.
The app reads that catalog and restores a validated matching record. Conflicts
and invalid settings stop before editor display. Native macOS, Linux terminal,
and Bun startup checks pass. Node reports an unavailable process host when
recovery is enabled. The demo bypasses these settings when no source path is
set. File dialogs, disk save, normal recovery-directory selection, protected
close, and scheduled session cleanup remain separate work.

Command-Z and Command-Shift-Z use Bend Undo and Redo. Command-A, Command-C,
Command-X, and Command-V use native selection and clipboard actions. Paste inserts
plain text. History commands wait while IME marked text is active. The native
editor does not automatically replace quotes, dashes, spelling, or text snippets.

On Linux, the same Bend program uses a multiline terminal checkpoint. Enter
replacement text and finish with `.apply` on its own line. Use `.undo`, `.redo`,
or `.close` as the first line for those commands. `.return` applies the same
Return command at the current projected selection. See
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
compiled cursor-mapping cases, and platform adapter tests. CI runs the same batch
on macOS and Ubuntu.
The native recovery batch includes separate writer and reader processes with
three distinct one-MiB snapshots. It also checks the atomic host's eight-MiB
input limit. These controlled process exits do not establish power-loss safety.
The large journal also has five interruption cases: creation, partial write,
complete write, file sync, and rename. Each case uses a new recovery process.
Recovery also checks external one-MiB file changes after the writer stops.
Unknown saved baselines produce a conflict and retain both complete versions.
The JavaScript batch also checks a one-MiB version 2 recovery codec round trip.
With Bun, the JavaScript batch also runs large disk restart, interrupted journal,
and conflict checks. Node runs the codec; Bend 2.0.34 file-byte effects require
Bun for these JavaScript disk checks.
`src/RecoveryEntry.bend` is the document identity prototype. Its checked wrapper
binds a save-state record to a nonempty host-supplied identity. Files with equal
saved bytes must not share recovery entries. A POSIX path identity provider is
now connected to the restart fixture. Application journal lookup and identity
lifecycle handling remain incomplete.
Separate-process checks now persist the wrapper with three one-MiB snapshots
and test two files with identical saved bytes. The owner is restored; the other
file is rejected. Both files and the journal must remain unchanged by the reader.
The provider checks resolved paths for existing readable regular files. Its
checks cover relative paths, symbolic-link aliases, Unicode names with spaces,
different destinations, and identity stability after atomic replacement.
Case and Unicode alias checks follow the filesystem's actual behavior. Hard
links keep separate destination identities; atomic replacement of one leaves
the other file unchanged.
`src/RecoveryLookup.bend` selects validated entries by exact identity. It retains
duplicate owners as an ambiguous result and retains candidates on invalid
requests. Filesystem enumeration and invalid-file reporting remain incomplete.
The read-only recovery directory host supplies enumeration and bounded record
reads. `src/RecoveryScan.bend` validates its complete listing, decodes records, and
retains rejected names and reasons. Connected scan and exact-identity lookup
checks run in the native and Bun batch. Application storage and editor
integration remain incomplete.
The batch also checks a directory whose listing exceeds the host limit. Both
the host and Bend scan must report failure, and every candidate must remain.

For an isolated local Linux run with Docker:

```sh
sh tests/linux.sh
```

This builds an Ubuntu 24.04 test image with the checksum-verified Bend 2.0.34
release. It mounts the repository read-only and runs the batch from a container
copy. The image stays available for later runs; the test container is removed
after it exits. The image now includes Bun 1.3.11 from a digest-pinned image.
Bun runs the generated file-byte, save, and recovery checks. Node remains
available. Other environments without Bun report omitted JavaScript file-byte
checks explicitly. Native Linux byte reads still run.

`src/CursorMap.bend` maps positions between Markdown source and visible render text.
It uses the renderer's runs, including escaped marks and unfinished spans.
Positions count Unicode scalars. They are not UTF-8 byte offsets, native UTF-16
offsets, or grapheme boundaries. `src/Projection.bend` uses the same map for active
run visibility. `src/DirectState.bend` owns source edits, selection, undo, and redo.

`src/TextPosition.bend` converts Unicode scalar positions to native UTF-16 positions
and back. A position inside a surrogate pair moves to the following scalar
boundary. Scalar range replacement supports forward and reversed selections.
The batch checks emoji, Chinese text, combining marks, newlines, and positions
past the document end. These conversions do not supply grapheme navigation.

On macOS, the batch also opens the real native window and sends selection,
emoji input, history shortcuts, marked-text composition, and deletion events.
It checks the Bend source, visible text, and cursor after each complete event.
This checks the native marked-text lifecycle, not a keyboard IME translator.

See [ROADMAP.md](ROADMAP.md) for experiment checks and remaining work.

`src/Blocks.bend` parses a source-preserving block subset. `src/Document.bend` retains
unchanged block identifiers and reparses the affected region after a scalar edit.
It keeps parser state between chunks and reuses the suffix at a settled boundary.
`src/BlockIndex.bend` stores blocks in an AVL tree. Cached source lengths locate
edits without a prefix scan. Tree splits and joins share unchanged branches.
The batch compares these updates with a full parse, including newline and fence
changes. Each edit-history snapshot stores cursor positions and its parsed
document. The document tree is its only source-text storage. Direct edits share
unchanged branches, and undo restores prior blocks and identifiers. Full source
strings are produced when the host or a reference test requests them.

`Document.apply_change` also reports the first replaced block, removed count,
and added count. Unchanged prefix and settled suffix blocks keep their text,
kinds, and identifiers. This interval can include an unchanged parser anchor.
The batch checks these bounds and preservation rules, including one-MiB local
edits and an opening fence that changes the rest of the document. Direct edits
read the parser range and the previous and new selection ranges through tree
paths. Blocks outside those ranges keep their cached scene runs and local maps.
Selection changes use the same range path without a parser change. The previous
selection range moves with retained blocks after insertion or deletion.
The scene position index supports balanced range insertion and removal.
Batch checks compare its cursor maps with complete index builds. In the one-MiB
fixture, local edits read three to five blocks out of 66,577 blocks. A selection
move between the document ends reads two blocks. These are scene refresh counts,
not frame-time measurements. Local updates now send ordered scene patches with
only affected chunks. The same fixture sends two or three chunks for local edits.

`src/BlockScene.bend` supplies native block runs and source positions. The editor uses
one ordered scene-transfer effect for all runs; the single-run API sends a
one-item batch. The adapters keep exact text, run order, and style codes.
Headings use
six font sizes. Quote lines and list items use paragraph styles and retain their
source prefixes. Fenced code stays literal and uses a monospace font. Its fence
marks show when the block is active. The native block test checks the exact text,
source, cursor, heading font, code font, and an edit followed by undo.

Run `sh tests/bench.sh` for the 100 KiB and 1 MiB document measurements.
The full batch also runs `sh tests/memory.sh`. It checks 20 one-MiB parse/edit
cycles against a 200 MiB process peak limit to detect retained tree branches.
This check does not measure the product idle-memory or native frame targets.
On macOS the batch also checks a 100 KiB native document, 20 direct edits, the
initial cursor, and scrolling to the end, middle, and start. Run
`sh tests/native_bench.sh` for the separate 100 KiB and 1 MiB native measurements.
The native adapter reuses style attributes and updates a changed text interval.
It can split this interval around a verified common middle section, with a
bounded search for the matching text and checks of its attributes.
The edit session keeps the current Bend scene and a balanced position index.
Cursor conversion uses tree paths and a local block map. A block cache uses
stable identifiers and local selection positions to reuse unchanged block scenes.
Equal block counts also reuse unchanged position-index branches. Complete scalar
maps, complete run lists, and combined visible strings are built only for
reference checks. The native adapter caches attributed block scenes, refreshes
changed blocks, and keeps only blocks in the current presentation. Direct edits
send scalar source ranges and inserted text; selection changes keep source text.
Opening, history, and raw-source replacement still send complete source text.
Local edits and selection changes send explicit block and UTF-16 patch ranges.
macOS updates its retained attributed scene and keeps untouched native chunks.
POSIX and JavaScript apply the same ordered patches to their fallback chunks.
Opening, history, and raw-source replacement still build complete scenes.
With a known native baseline, macOS applies scene patches directly to the text
field. It adjusts patch ranges for text already changed by native input. An
unknown baseline or a partial overlap uses complete comparison as a fallback.
Normal native input uses the reported text-storage edit range and compares only
text within that range. Multiple storage edits before a commit retain complete
input comparison. Replacement boundaries preserve complete composed characters.
Model edit timing does not establish native editor performance.
The macOS source mirror uses a balanced scalar-to-UTF-16 index. Position lookups
scan one leaf of at most 512 UTF-16 units. Edits retain unchanged index branches.
Native source-field notifications track its baseline, so normal source updates
do not compare complete strings. Independent changes require source restoration.
TextKit can lay out separate text regions. Projection keeps the caret visible;
native document checks verify caret visibility after each edit and remote scrolls.
The native batch also types before the initial complete-layout scroll. Benchmark
arguments `cold` and `large-cold` select this path; add `-stages` for stage clocks.
Complete scene rendering forks independent document-tree branches for large
documents. The opening scan batch compares every result field with the sequential
scan. `tests/OpeningBench.bend` separates parsing, block scanning, and cache finish.
Large empty caches use identifier-bit partitions to build independent branches.
The cache check compares the complete result with sequential insertion, including
duplicate identifiers and the last-update rule. Existing caches update incrementally.
Key preparation and identifier partitions use accumulators to limit temporary
memory. Key preparation finds the maximum identifier in the same pass.
The macOS chunk builder collects text and style ranges before creating its
attributed buffer. Host checks compare multi-run chunks with single-run output.
The native navigation batch drives real text-view commands through the event
loop. It checks Unicode cluster movement, long wrapped text, selection extension,
and edit-surface resizing without manual input.
[BENCHMARKS.md](BENCHMARKS.md) records the reference system, method, results, and
remaining performance limits.

## List, task, and quote preview

List markers and quote marks hide outside the active item or line. Select a
list marker to edit its source. Click a task checkbox to change its state.
Undo restores the exact original marker, including uppercase X. Source mode
shows the original marks and keeps the same history.

## Formatting controls

Bold, Italic, and Code format selected text. Their shortcuts are Command-B,
Command-I, and Command-Shift-C on macOS; use Control on Windows and Linux.
With no selection, they insert marks and put the cursor inside. The heading
menu changes a top-level line to Heading 1–6 or Paragraph. Command-Option-1–6
on macOS and Control-Alt-1–6 on Windows/Linux select heading levels.
Commands use one selection and the shared Undo history in both display modes.
Inline formatting requires one line. Heading commands inside lists, quotes,
and code blocks remain unsupported. End a table cell edit before formatting
document text.

Link opens text, destination, and optional title fields. Command-K on macOS or
Control-K on Windows/Linux also opens them. Apply Link adds or changes a link;
Remove Link keeps its text. Cancel leaves the source unchanged. Forms opened
before a source edit must be opened again. Unchanged fields keep their original
spelling. Relative destinations and spaces are supported. Use %3C and %3E for
angle brackets. Reference links can be removed here; edit their shared
destinations in Source mode. Links do not yet open their destinations.
