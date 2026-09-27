# MarkBend Product Target

## Product statement

MarkBend is a native Markdown editor for focused writing. It shows the formatted
document in the edit surface. It shows Markdown marks only when the writer needs
them. The Markdown source is always the primary document.

MarkBend uses Bend for the document model, edit rules, parsing, incremental work,
and correctness proofs. A small native host supplies operating-system services
that Bend does not supply well.

## Final user experience

A writer can open a Markdown file and edit the formatted document directly.
The cursor, selection, and undo history remain stable when Markdown marks become
visible or hidden. Save does not replace valid source with generated Markdown.

The final product must support:

- CommonMark and useful GitHub Markdown extensions.
- Headings, paragraphs, links, emphasis, strong text, lists, task lists, quotes,
  code, tables, footnotes, images, mathematics, and front matter.
- Chinese, Japanese, Korean, bidirectional text, emoji, and combining marks.
- Native IME, clipboard, drag and drop, file dialogs, and accessibility.
- Search, replace, outline navigation, themes, and document tabs.
- Crash recovery, atomic save, file-change detection, and conflict handling.
- PDF and image export.
- Responsive editing of a 1 MiB document.
- macOS and Linux. Windows is a target when the Bend or host toolchain permits it.

## Source-of-truth rule

The Markdown byte sequence is the only saved representation. The formatted edit
surface is a projection of that sequence. Every visible item has a source range.
Rendering must not silently normalize or replace source text.

## System boundary

### Bend core

The Bend core owns:

- The byte buffer and stable positions.
- Edit commands and edit history.
- Markdown block and inline parsing.
- Incremental invalidation and parsing.
- Source-to-view and view-to-source mapping.
- Formatting-mark visibility decisions.
- Layout input and independent parallel work.
- Laws and their proofs.

### Native host

The native host owns:

- The window and event loop.
- Keyboard, pointer, IME, and accessibility events.
- Clipboard, file dialogs, file watching, and atomic file replacement.
- Font discovery, shaping, glyph rasterization, and GPU presentation.
- Image decoding and operating-system integration.

The host must not contain document semantics. It sends explicit events to the
Bend core and draws an explicit scene from the Bend core.

## Performance targets

- A key event updates the next frame in less than 16 ms at the 95th percentile.
- A 1 MiB document opens to a readable first frame in less than 150 ms on the
  reference computer.
- A local edit reparses only the required Markdown region.
- Independent block analysis uses balanced parallel calls when the work is large
  enough to repay scheduling cost.
- Idle memory for a 100 KiB document stays below 100 MiB.

These values are product targets. Benchmarks must define the reference computer,
input files, build mode, and sample count.

## Correctness targets

The proof gate is `bend PROOF.bend`. Important rules belong in `LAWS.bend`.
The target laws cover:

- Source preservation.
- Valid cursor and selection positions.
- Edit and inverse-edit behavior.
- Undo and redo behavior.
- Full and incremental parser equivalence.
- Exact source-to-view mapping.
- Safe save and recovery state transitions.

Foreign effects are outside the Bend proof boundary. Integration tests must
check their contracts.

## Delivery stages

### Experiment 1: cursor buffer and formatting projection

Prove insert and backspace behavior, cursor movement behavior, and the direct
formatting projection. Measure the cost of independent work on both sides of the
cursor.

### Experiment 2: native editable paragraph

Connect the Bend model to a native window. Support Unicode text, selection,
strong text, emphasis, undo, redo, and IME composition in one paragraph.

The first step uses a narrow native commit field. This validates Unicode, IME,
and Bend-owned history before a future host API supplies continuous edit events.

### Experiment 3: incremental Markdown document

Add block parsing, lists, quotes, code fences, stable block identity, scrolling,
and large-file benchmarks.

### Product increments

Add tables, images, mathematics, export, document navigation, accessibility,
recovery, and platform packages. Each increment must keep the proof gate and
performance budgets green.

## Non-goals for the first experiments

- Full MarkView feature parity.
- A pure-Bend font shaper or platform toolkit.
- GPU work for small or unbalanced edit operations.
- HTML as the internal document model.

## First release gate

The first public release is ready only when a writer can use direct formatting
with a Chinese or Japanese IME, undo every edit, recover an interrupted session,
and save without source loss.
