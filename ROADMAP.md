# MarkBend experiments

The product requirements are in TARGET.md. This file tracks development work.
Run each experiment as a complete batch. Do not require manual checks for each
small change. Keep the goal open until the required evidence is available.

The user approved CodeMirror 6 in a desktop WebView on 2026-10-04.
The new source is in src/web/ and src/desktop/. CodeMirror owns input and history.
Bend supplies edit commands. The old native adapter remains as reference code.
The timing batch remains stopped. Its partial records are not a migration gate.

Migration gates:

- Actual desktop window, input, exact source history, Open, and safe Save.
- Live preview, source reveal, math, Mermaid, isolated HTML, and code highlighting.
- Table-cell editing, full IME checks, recovery, and platform checks.

Old adapter results below are historical evidence. They do not prove these gates.

### Desktop footnote-math milestone

Implemented: MathJax renders package-parsed inline and block formulas inside
footnote definitions. The app includes the font data. Invalid formulas keep
literal text and an edit hint without removing other note content. Removed
definitions cancel pending formula publication. SVG has no link or resource
actions. Rendering uses no source or history transaction. Native acceptance and
large-document rendering cost remain unverified.

Checks: 163 web checks, the app-only debug macOS build, and the root Bend proof
pass. Formula checks cover inline and block SVG, invalid TeX, retained note text,
exact mixed-ending history, Source mode, source reveal, and late success/failure
results. Browser inspection confirms readable fraction and integral layout,
literal invalid formula text, and retained complete source. Architect review
found no remaining blocker for this feature checkpoint.

### Desktop footnote-command milestone

Implemented: Footnote inserts a reference after selected text and appends a
top-level definition. The package validates both additions before the command
dispatches one outer history edit. It selects new note text for replacement.
Label selection reserves existing definitions and missing references. Original
text and trailing whitespace stay intact. Go to Footnote navigates to the first
accepted definition or its first reference without a source edit. Both commands
use the existing input guards. References within definitions remain open.
Insertion requires a single-line selection. Native command acceptance remains
unverified.

Checks: 159 web checks, the app-only debug macOS build, and the root Bend proof
pass. Browser checks cover toolbar insertion, selected note-text replacement,
navigation in both directions, and separate Undo of text replacement and the
complete insertion. Architect review found no remaining commit blocker.

The previous macOS disk-image build failed in bundle_dmg.sh after the executable
and app bundle built. An app-only debug build passed. Disk-image packaging stays
unverified; it is separate from native input acceptance.

### Desktop footnote milestone

Implemented: upstream GFM footnote parsing, source ranges, first-use numbering,
repeated references, first-definition duplicate handling, and source reveal.
Definition preview retains text and formatting without active links or resources.
Definition headings stay out of the outline. Controls reject note source and
Return in definitions inserts a plain newline. Source mode keeps the same model
and outer history. HTML and math inside definitions remain literal; images show
alt text. References inside definitions, insertion controls, navigation, and
large-document timing remain open. Native and Windows/Linux acceptance are open.

Checks: 153 web checks, the production web build, and the root Bend proof pass.
Browser checks cover first-use numbers, repeated references, missing-reference
marks, definition source reveal, typed edits, Undo, and Source mode. Range checks
cover BOM and mixed endings, Unicode, duplicate definitions, nested containers,
metadata, HTML/code/math contexts, and control guards. Architect review found no
remaining blocker for this feature checkpoint.

### Desktop front matter milestone

Implemented: CodeMirror's mixed YAML front matter and Markdown language package.
The app uses parsed metadata boundaries and preserves body offsets. Closed and
empty metadata have a literal preview with source reveal. Active and unclosed
metadata stay editable YAML source. The package requires exact three-dash lines
at document start; three dots and trailing spaces do not close metadata.
No YAML value becomes app configuration or an executed effect. Metadata is
excluded from the outline, Markdown preview, and image reference definitions.
Formatting and link/image controls reject metadata. Return is plain inside
metadata, so YAML list spelling cannot start Markdown list continuation.
Native front matter and Windows/Linux input acceptance remain open.

Checks: 145 web checks, the root Bend proof gate, and the debug macOS app build
pass. Metadata checks cover BOM and mixed CRLF/CR/LF source history, empty and
unclosed blocks, closing-mark edits, metadata/body Return boundaries, source
controls, literal rendering, body heading offsets, and image references. Browser
checks cover metadata preview, body-only outline, source reveal, plain Return
inside a YAML list, Undo, and Source mode. Native acceptance remains unverified.

### Desktop image-controls milestone

Implemented: Image controls for alt text, destination, title, insertion, update,
and removal. The keyboard command is Command-Shift-I on macOS and Control-Shift-I
on Windows/Linux. Commands share the source-preserving link implementation with
an explicit image kind and image destination checks. Changed fields use one
outer history transaction. Unchanged fields retain raw spelling. Remove retains
raw alt source and shared reference definitions. Reference updates remain edits
in Source mode. Composition, read-only state, stale captures, multiple selections,
and unsupported source blocks reject commands.

Choose Image only fills an encoded absolute path. It does not copy or write an
asset. Picker request tokens reject late results after cancellation, reopening,
field input, source changes, or composition. Windows drive and UNC spelling has
Markdown round-trip checks; the Windows-only host path tests need a Windows run.
Relative asset insertion, drag/drop, paste images, local SVG, table-cell images,
and native image-control acceptance remain open.

Checks: 138 web checks, 18 Rust checks, the root Bend proof gate, and the debug
macOS app build pass. Browser checks cover the keyboard command, form insertion,
existing-image capture, raw alt removal, and one-step Undo. Web checks cover exact
BOM and mixed-ending history, unchanged raw fields, reference removal, stale
captures, composition, picker cancellation and late results, and path encoding.
The native file picker and Windows-only host path tests remain unverified.

### Desktop image-preview milestone

Implemented: source-reveal image widgets with package-parsed inline and reference
destinations, titles, and plain alt text. Local paths resolve from the host's
document directory. Percent escapes decode once. Local reads check document
generation before publication and use bounded regular-file reads and raster
signatures. Local and data images support PNG, JPEG, GIF, and WebP up to 8 MiB.
File transitions refresh image context even when the path stays unchanged.
Reference-definition edits refresh images. Removal ignores pending results and
releases Blob URLs. Image errors retain editable source and alt text.

Checks: 130 web checks, 18 Rust checks, the root Bend proof gate, and the debug
macOS app build pass. Browser checks cover data-PNG decoding, decoded and
formatted alt text, source reveal, Source mode, Undo, and Redo. Integration checks
cover local IPC requests, reference changes, same-path refresh, failures, stale
results, Blob release, data limits, and literal image spelling in code and math.
Actual native local-image IPC and native image UI acceptance remain unverified.

Remote HTTPS images use the browser image loader without a referrer. Network
requests expose the client address. Remote images can use browser-supported
formats, including SVG, and have no app byte or dimension limit. Native CSP
restricts remote image resources to HTTPS; app code does not validate each
redirect destination. Local byte limits do not bound decoded image memory.
Local SVG, image insertion, images in table cells, full native image acceptance,
and Windows/Linux checks remain open.

### Desktop file-change milestone

Implemented: bounded read-only byte checks against the saved baseline, visible
window polling, focus checks, Check File, and a warning with Reload and Save As.
Checks do not overlap. Late results and errors are ignored after file transitions.
The host captures its baseline under the lock and reads outside the lock. Reload
waits for discard confirmation and recovery acknowledgment. A valid read opens
the exact source with a new history. Failed reads and cancellation retain source
and baseline. Uncertain Save blocks Reload and Save As until Check Save succeeds.

Checks: 122 web checks, 16 Rust checks, the root Bend proof gate, and the debug
macOS app build pass. Checks cover exact bytes, atomic replacement, missing and nonregular files,
invalid UTF-8, document generations, stale results and errors, command and
composition guards, Reload cancellation, recovery failure, and exact source
history. Native UI acceptance remains open. Matching saved bytes do not prove
file identity. An external write after the final comparison or read remains
possible; Save still uses its own baseline checks.

### Desktop source-editor milestone

Implemented on 2026-10-04: CodeMirror input and history, exact source record,
Bend Return commands, native Open and Save dialogs, file-baseline checks,
atomic replacement, save-completion checks, and unsaved window-close protection.
File commands defer during composition. New resets both editor and host state.

Checks: 19 web checks, five Rust checks, ListReturnCheck, and root Bend proof pass.
The debug macOS app bundle builds. Actual WKWebView checks cover typing,
numbered-list Return, Unicode paste, Undo, Redo, Save As, Open, Save, input after
a toolbar click, and cancellation of Close with unsaved text. Saved bytes were
checked in /tmp/markbend-webview-check.pifopn/desktop-check.md.

The architect reviewed source/history and file ownership and required the save
uncertainty, reset, bounded-read, and composition corrections before this commit.
This milestone was a source editor. The next milestone below adds live preview.
Complete keyboard IME sessions, application Quit, crash recovery,
file watching, and Linux/Windows GUI checks remain open. Save checks cannot
exclude an external write between the final comparison and atomic replacement.

### Desktop live-preview milestone

Implemented on 2026-10-04: formatted Markdown, source reveal, Source mode,
MathJax 4 inline and block formulas, Mermaid diagrams, isolated HTML, table
preview, and code highlighting. The existing micromark math extension supplies
source ranges. MathJax supplies the TeX parser and bundled SVG fonts. There is
no new TeX parser. Preview widgets do not replace the saved source record.
Removed widgets discard pending renderer results. HTML has no scripts,
same-origin access, or external resources. Table preview excludes live links,
images, and HTML styles from the edit surface.

Checks: 30 web checks cover exact source history, source reveal, selection
boundaries, mode changes, composition guards, render errors, removed widgets,
and HTML isolation. The debug macOS QA bundle shows formulas, Mermaid labels,
HTML, table borders, and code colors. Formula source editing and Undo/Redo were
checked in the native window. The user's open windows and documents are kept.
The native rich-document Save As sequence has not yet been checked.

This is preview with source editing. Direct table-cell editing, full keyboard
IME sessions, math accessibility, application Quit protection, crash recovery,
file watching, and Windows/Linux GUI checks remain open.

### Desktop table-cell milestone

Implemented: a CodeMirror edit surface inside a rendered table cell. It edits
single-line Markdown and sends source patches to the outer CodeMirror history.
Tab and Shift-Tab move between cells. Enter and Escape end the cell edit. The
Table source button reveals the complete table. Source mode and file commands
defer during cell composition. Removing the table destroys the cell view.

Checks: 39 web checks pass, including exact source restoration with a BOM,
mixed endings, alignment rows, cell padding, empty cells, escaped pipes,
Unicode, typed edge spaces, and structural removal. Tight cells normalize an
odd final backslash before a delimiter by adding a second backslash. The cell
text reflects this change, and one Undo restores the original source.
Native macOS checks cover Unicode and pipe input, Undo/Redo, Tab, source reveal,
and Save from inside a cell. The saved bytes match the expected source in
/tmp/markbend-table-check.0F8UhU/table-check.md.
The final rebuilt Table Verify app also confirms that Enter and Escape retain
the rendered table after the cell edit ends.

Row/column operations, multiline cells, missing trailing cells in short rows,
full IME sessions, and Windows/Linux checks remain open. This milestone does
not complete the Typora target.

### Desktop table structure milestone

Implemented: Row above/below, Delete row, Column left/right, Delete column,
and Align left/center/right buttons. Plans validate new source ranges before
ending the active cell edit. Each command uses one outer history transaction.
The header and last column stay in the table. Commands inside lists or quotes
are disabled with a Table source hint. Nested previews use individual row
ranges, so container prefixes stay in source without breaking the preview.

Column patches retain existing slots, including padding and escaped pipes.
Short rows get explicit missing slots when a column command needs them.
Empty edge slots and one-column results get required outer delimiters.
New header cells use Column. New rows use the first source line ending.
Alignment changes retain the existing number of dashes. No-op alignment
does not add a history event.

Checks: 46 web checks pass. Exact Undo/Redo checks cover all commands, BOM,
mixed endings, Unicode, escaped pipes, zero body rows, no final ending,
indentation, absent outer pipes, short and extra rows, and command guards.
Native macOS checks cover the buttons, focus after insertion, alignment,
Undo/Redo, deletion of the last body row, reduction to one column, and Save.
Saved bytes match /tmp/markbend-structure-check.IkT0UC/structure-check.md.
The final Structure Verify build confirms keyboard Undo returns focus to the
outer edit surface when it removes the active column, and keyboard Redo works.

Direct editing of omitted cells, multiline cells, nested structure commands,
full IME sessions, and Windows/Linux checks remain open.

### Desktop omitted-cell milestone

Implemented: direct editing of omitted cells in short table rows. Selecting a
cell or using Tab leaves source unchanged. First accepted input appends only
the required slots and text in one history transaction. Actual source slots
remain separate from virtual edit ranges. Undo returns to the virtual cell;
Redo restores its text and exact active range. Whole-row replacement ends the
cell edit. Lezer delimiter nodes distinguish a trailing separator from an
escaped pipe in cell text.

Checks: 52 web checks pass, including exact source/history for BOM, mixed
endings, several omitted slots, spaces-only input, nested prefixes, Unicode,
escaped pipes and backslashes, trailing padding, source mode, prefix edits,
rejected multiline input, and stale row replacement.
Native macOS checks cover opening an omitted cell, Tab to another omitted
cell, Unicode and pipe input, Undo back to empty, Redo, and Save from the cell.
Saved bytes match /tmp/markbend-omitted-check.l0GzWR/omitted-check.md.
Multiline cells, nested structure commands, full IME sessions, and platform
checks remain open.

### Desktop search and outline milestone

Implemented: CodeMirror search/replace panel with keyboard shortcuts, next and
previous matches, Replace and Replace All, case, whole-word, and regexp options.
Search uses normalized Markdown source. File bytes keep their BOM and original
line endings. Search and replace defer during outer or cell composition, even
when called from the package panel. Find ends cell editing before source reveal.
Outline navigates parsed headings in both modes, adds no history, uses text
labels, and refreshes after incremental parsing. Underlined headings now use
their correct levels in both preview and outline.

Checks: 58 web checks pass. New checks cover multiline and Unicode replacement,
exact mixed-ending/BOM Undo/Redo, invalid and empty regular expressions,
zero-length matches, hidden widget source, composition guards, safe outline
labels, mode changes, history, and parser completion.
The macOS test app passed Replace All across ordinary text and table source,
one-step Undo/Redo, outline scrolling in both modes, Find from a table cell,
and hidden formula source reveal. UI control failed during the final Save As
check. No fixture was saved, so that native byte check remains unverified.

### Desktop list, task, and quote milestone

Implemented: parser-based list markers, task checkboxes, and quote line styles.
Ordered numbers and marker spelling stay unchanged. Selection inside an item
reveals its marks, including continuation lines and multiple selections.
Nested quote lines use one border with a depth. Code, table, and HTML source
does not acquire list widgets. A task toggle validates its current marker,
changes one character, and uses outer history. Composition and read-only
states reject marker commands. Detached widgets cannot change source.

Checks: 66 web checks pass. The new batch covers nested lists and quotes,
empty items, tabs, Unicode, checked x/X, mixed endings and BOM, exact task
Undo/Redo, Source mode, selection reveal, code fences, and composition guards.
The macOS test app passed mouse and keyboard task toggles, uppercase X Undo,
Redo, continuation-line source reveal, and list/quote layout beside formula
and table widgets. The final build removes extra bullets before unordered
task checkboxes and supplies each checkbox with its task text label.
Saved bytes match /tmp/markbend-block-check.BNmcy4/block-check.md after
uppercase X Undo. The final MarkBend bundle also verifies the writing margins
and the table-cell padding override. Task text labels refresh after source
edits and Undo. The temporary final-app document was
cleared after the check.
The final Fonts QA bundle confirms monospace text in Source mode and the cell
editor, serif text in preview, and separate document/cell padding.
Nested Return commands and full native IME sessions remain open.

### Desktop direct-formatting milestone

Implemented: Bold, Italic, Code, top-level Heading 1–6 and Paragraph controls,
with keyboard shortcuts. Parsed delimiter ranges control removal. New nonempty
inline spans are accepted only when the resulting syntax matches the requested
format. Code commands choose safe backtick runs and CommonMark padding. Empty
selections insert editable marks. One outer transaction supplies each command;
preview and Source mode retain the same exact source and history.

ATX conversion removes parsed closing marks. Single-line Setext conversion
removes its underline and retains the text line ending. Selection ending at the
next line start excludes that line. Commands defer during composition and reject
read-only state or active table cell edits. Incomplete parsing cannot make a
code block into a guessed paragraph. Rejections keep source and selection.

Checks: 77 web checks pass. The formatting batch covers exact mixed-ending/BOM
Undo/Redo, Unicode, backward selection, nested styles, escapes, empty marks,
edge spaces, code delimiters and padding, ATX/Setext conversion, Source mode,
unsupported selections, composition, and a distant unparsed code block.
The native macOS batch passed Bold/Italic/Code shortcuts, button commands,
nested styles with inner-style Undo/Redo and removal, safe backticks, code
padding, ATX closing marks, Setext conversion, Source mode, and Heading 6 from
the menu. Saved bytes match /tmp/markbend-format-check.NKfoOU/format-check.md
after formatting round trips. The default app bundle builds with this feature.
Link controls, multiline formatting, container heading commands, and native
IME checks remain open. This milestone does not complete the product target.

### Desktop link-controls milestone

Implemented: Link and Command/Control-K open text, destination, and optional
title fields. Apply and Remove use one outer history transaction. Cancel and
opening the form create no transaction. A captured source record, document,
and monotonic generation reject stale Apply/Remove, including history restored
text and new document states. Input guards also cover read-only state, outer
and child composition, and active table-cell editing. Escape stays with the
input method during form composition.

Field patches retain unchanged label, URL, title, escapes, and separator
spelling. Package parsers validate the complete Link span before acceptance.
Destination checks include Markdown escape/entity decoding. Raw angle brackets
require URL encoding. Single-line fields can retain existing multiline
separators. Reference links can be removed without changing shared definitions.
Their inactive reference suffix now hides in preview and reveals for editing.

The web batch covers exact BOM/mixed-ending Undo/Redo, Unicode, nested label
styles, brackets, parentheses, title quotes, relative destinations, encoded
angles, unsafe schemes, stale forms, no-op fields, empty selections, reference
removal, Source mode, input guards, form composition, and Cancel. All 92 web
checks and the isolated macOS desktop build pass. Native link checks remain
unverified: the UI tool reports cgWindowNotFound for the running Link QA process.
Host logs show that it created a visible but occluded window. No product change
was made from this UI observation failure. Link navigation, reference destination
controls, and multiline fields remain open. The full product target stays open.

### Desktop theme milestone

Implemented: System, Light, and Dark themes with a local preference. System
follows the operating-system color preference. Theme changes update CSS without
editor transactions, so source, history, selection, and active cell views stay
intact. Controls, search, outline, table cells, math, caret, selection, and code
tokens use the palette. HTML and Mermaid retain a light canvas for authored
colors. The 95-check web batch includes palette contrast and unchanged editor
state during outer and cell composition. The macOS bundle builds. Browser
checks confirm Light/Dark Find text fields, buttons without gradients, focus,
and match colors. Native WebView visual checks remain open.

### Desktop nested Return milestone

Implemented: nested list, task, quote, and continuation-line Return through
CodeMirror's Markdown command. Flat list and ordinary Return keep the Bend
planner. Empty nested items exit one level, tasks reset to unchecked, and
consecutive ordered siblings can renumber in the same history transaction.
Code, HTML, and table source use plain Return. Incomplete syntax and rejected
package commands also use plain Return. Source history retains exact BOM and
mixed endings. Package inserts use the first source ending; Bend inserts use
the current-line ending. Native keyboard checks remain open.
The WebView Bend bridge now parses normalized text and maps its scalar ranges
back to exact raw source; this also fixes bare-CR Return in this bridge. The
legacy native parser is unchanged. The app owns Enter precedence and retains
the package's other Markdown bindings. Checks include actual Enter events,
ordered siblings, nested task reset, Unicode cursor mapping, and exact history.
All 112 web checks, root Bend proof, and the macOS desktop build pass. Full-tree
completion has a 50 ms budget; it can delay Return and fall back to a plain
newline. This does not prove the 16 ms frame target. Native keyboard and large
document performance checks remain open.

### Desktop recovery milestone

Implemented: exact source checkpoints after a 500 ms input delay, with a 2-second
maximum scheduling wait during continuous input, a serialized
queue, atomic host publication, bounded validated reads, session leases, and
monotonic revision checks for writes and clears. Renderer starts rotate tokens
and retain previous copies. Recovery offers inactive-session copies at startup
or from its button. Restore opens an untitled unsaved document, keeps the copy,
and does not associate the original file baseline. Save with later edits or
uncertain completion retains dirty recovery source. Failed transitions preserve
current source; failed Close keeps the window open. Retry recovery is explicit.
All 118 web checks, 13 Rust checks, root Bend proof, and the macOS desktop build
pass. Checks cover exact BOM/mixed endings, stale writes/clears, session leases,
renderer restart with and without a copy, publication uncertainty and clear
retry, invalid records, continuous input, queue failures, Restore cancellation,
failed Restore, Save with later edits, and failed Close. The isolated QA build
also passes, but UI selection returned cgWindowNotFound. Native recovery
acceptance remains unverified.

The latest unconfirmed input can be lost before the checkpoint acknowledgment.
Orphan-copy removal, application Quit protection, native crash/restart checks,
Windows directory durability, and Windows/Linux acceptance remain open.

## Experiment 1: cursor buffer and formatting projection

Implemented: basic cursor buffer, source reconstruction, insert, backspace,
cursor movement, and simple formatting projection. Laws cover specified cases.
The independent cursor work measurement is an early model, not evidence for the
final document performance targets.

## Experiment 2: native editable paragraph

Implemented:

- macOS multiline source input and automatic formatted preview.
- Bend-owned undo and redo.
- Native clipboard commands and composition event suppression.
- Strong text, emphasis, inline code, and plain-text escaped marks.
- Unicode scalar source-to-view mapping.
- Scalar-to-UTF-16 conversion and scalar selection replacement.
- Native selection events connected to source-to-view mapping.
- Direct formatted editing with exact source marks in active runs.
- Source and formatted-surface selection restored by undo and redo.
- A real native event-loop test for selection, emoji input, undo, redo,
  active marks, marked-text composition, and deletion.
- Automated native, POSIX, and JavaScript adapter checks.

Remaining checks and implementation:

- Check keyboard IME translation. Native marked-text tests check composition
  lifecycle and event suppression, not a complete input-method session.
- Supply grapheme-safe editing for emoji sequences and combining marks.
  The native change-range adapter already expands edits to composed-character
  boundaries; the Bend core still uses scalar positions.

## Experiment 3: incremental Markdown document

Implemented:

- Source-preserving block parsing for headings, paragraphs, individual list
  items, quote lines, blank lines, and backtick or tilde code fences.
- Stable identifiers for unchanged prefix and suffix blocks.
- Updates that start at the previous block and stop at a settled boundary.
  Parser state continues across chunks. Open fences and joined lines can require
  more blocks; unchanged suffixes are shared without reparsing.
- Differential checks against a full parse at each source position in the
  fixture set, plus a sequence of 40 edits.
- Checks with one and four CPU threads.
- Independent parallel reversals for suffix reconciliation.
- An AVL document index with cached scalar lengths, block counts, and heights.
  Source-position lookup and block splits use tree paths. Local edits share
  unchanged branches. Full construction consumes the block list once.
- Index checks against a simple list model, including split boundaries, source
  positions, tree balance, cached lengths, and sizes around powers of two.
- A native process-memory gate for 20 one-MiB parse/edit cycles. It detects
  retained tree branches and is separate from the product idle-memory target.
- Large-file measurements, with results and limits in BENCHMARKS.md.
- Parsed documents stored in edit-history snapshots and updated by direct edits.
- Source text stored only in the document tree of each history snapshot. Edits
  share unchanged branches instead of keeping a second complete source string.
  A history memory test checks every source character after 20 edits and each
  undo and redo step. This gate is separate from the product idle-memory target.
- Block scenes connected to the native editor, with headings, quote and list
  paragraph styles, and literal code fences.
- Native block tests for hidden and active marks, source mapping, fenced edits,
  undo, heading and code fonts, and scroll-view configuration.
- An automatic native 100 KiB test for the initial cursor, 20 direct edits,
  exact source and selection, native drawing, and scrolling to the end, middle,
  and start. The native adapter retains the selection sent before view creation.
- A separate 1 MiB native benchmark and a core scene benchmark. Native updates
  reuse style attributes and replace a changed interval instead of replacing
  the whole text storage. Requested fonts are retained across native fallback.
- A current-session scene cache, kept outside undo snapshots. Input conversion
  and native presentation reuse this cache. Text-position conversion stops at
  the requested position without building a full boundary list. Differential
  tests check these conversions and cached views after edits, selections, undo,
  redo, and raw-source replacement, with one and four CPU threads.
- Native range diagnostics that distinguish removed text from inserted text.
  The 100 KiB first edit removes the two heading-mark characters; the previous
  inserted-range-only measurement did not show that deletion.
- Native split updates for a verified common middle section. A bounded search
  finds an anchor, then checks all retained text and attributes. The tail patch
  runs before the head patch. Twenty-five mixed-script cases match a full
  native build. The measured first 1 MiB edit uses two patches of at most two
  UTF-16 units instead of replacing most of the document.
- Block scenes cached by stable identifier and local selection positions. Source
  positions in a cached scene are relative to its block, so prefix edits do not
  force unchanged suffix blocks to rebuild. The cache remains outside history.
  A binary trie supplies identifier lookup. It clears when its old entry count
  exceeds twice the current block count; after rendering it has at most three
  times the current block count. Tests check full-build equality, unchanged-view
  reuse, prefix shifts, 40 edits, cache size, and one and four CPU threads.
- A balanced scene position index with cached source lengths, UTF-16 lengths,
  block counts, and the last non-final source point. Input and cursor placement
  use tree paths and local block maps. Tests compare all fixture positions with
  complete maps, including hidden marks, empty fences, reversed selection,
  surrogate pairs, CRLF, undo, redo, history branches, and raw replacement.
  Equal block counts share unchanged index branches; different counts rebuild.
  Large balanced index construction uses independent parallel calls. A larger
  fixture checks this path with one and four CPU threads. Complete scalar maps
  and combined visible strings are now built only for reference checks.
- Native benchmark source checks that use a short pattern and edit count, with
  exact character and cursor checks after every edit. Complete expected source
  strings are not kept across edits. Optional native stage clocks separate run
  construction and projection from source delivery; normal frame measurements
  keep those clocks disabled. Results and limits are in BENCHMARKS.md.
- Scene runs sent through one host effect. The single-run API uses a one-item
  batch. Native consumption uses the runtime ownership helpers so shared cached
  scenes remain valid. macOS, POSIX, and JavaScript checks compare ordered batch
  output with single-run output, including every style, empty text, and Unicode.
  The generated JavaScript program is also run with no input in the batch gate.
- Ordered host chunks with stable block identifiers and a freshness flag from
  the Bend block cache. macOS and JavaScript reuse unchanged native scenes and
  keep only current blocks. Cache misses rebuild from supplied runs. Fresh
  entries replace prior content with the same identifier, including history
  resets. Legacy scene presentation clears the native cache. Host checks cover
  these cases; native benchmarks check at most two rebuilt blocks per local
  fixture edit. Complete Bend run-list joins are now only for reference checks.
- Source-range delivery for direct edits. Bend supplies scalar source positions
  and inserted text. Each adapter updates its source mirror; macOS converts the
  range to UTF-16 and patches the raw editor. Selection changes keep source text.
  Opening, history, and raw-source replacement keep the complete-source path.
  Checks cover reversed and clamped ranges, Chinese, emoji, combining marks,
  and CRLF. Native event tests compare the host and raw editor with Bend source
  after every action. Large native tests check the exact source after every edit.

Remaining work:

The document update now reports a conservative changed block interval: first
block, removed count, and added count. Tests check unchanged prefix and suffix
identifiers, kinds, and exact text at every fixture position, through 40 edits,
and for one-MiB edits. Direct edits now use this interval to replace the changed
scene index range. Tree paths find the previous and new selection ranges, so
local scene refresh does not scan complete document blocks. The old selection
range moves with retained block ranks after insertion or deletion. Scene index
chunks retain cached runs for blocks outside these ranges.
The scene position index now has balanced split, join, and range update
operations. Batch checks compare range updates with complete builds. These
operations run in the scene cache edit path. A one-MiB reference batch reads
three, four, and five blocks for edits near the start, middle, and end. A selection
move between ends reads two blocks. Local updates now send ordered patches with
block and UTF-16 ranges. The same one-MiB cases transfer two or three chunks.
Patch replay checks compare block order, exact native ranges, text, and styles
with complete scenes. macOS patches its retained attributed scene and keeps
untouched chunks; POSIX and JavaScript keep the same effect contract.

- Native navigation checks now cover document-end and document-start commands,
  left/right arrows, selection extension, Chinese, emoji, combining marks,
  joined emoji, an 8,192-character wrapped line, repeated selection changes,
  and three edit-surface sizes. They check exact source and selections and the
  visible caret. Up/down commands at the first line boundary also pass. Extend
  coverage to vertical navigation through variable-width text and bidirectional
  text. The wrapped-line check passes at column zero and column five in the
  repeated Latin paragraph, with both events passing through Bend.
  Down and Up across a wrapped line now pass separately through Bend. The host
  preserves selection affinity when the scene maps to the same native range.
  This fixes Up returning one position before the paragraph start.
  Programmatic full window frame changes preserve text, selection, and caret
  visibility. User drag resizing and automatic editor reflow remain unchecked.
- Meet the edit frame-time budget. Indexed model edits are within one millisecond
  at the 95th percentile. Measured complete editor frames exceed the target.
- Add full CommonMark block rules. Nested lists, lazy quote continuations,
  setext headings, indented code, thematic breaks, and HTML blocks are absent.
- Improve quote and list presentation. Their source prefixes still show.
- Native macOS source-range conversion now uses a balanced position index.
  Normal source-field updates use a tracked baseline. Reduce complete-source
  copies and opening cost. TextKit now permits separate layout regions, and
  projection keeps the caret visible. Normal input
  now compares only the text-storage edit range; multiple edits before a commit
  keep complete input comparison. Normal local edits use direct storage patches; unknown
  baselines and partial overlaps keep complete comparison as a fallback.
  Reduce complete-source history presentation.
  Native checks now include typing before the initial complete-layout scroll.
  Large complete renders now fork independent document-tree branches. Opening
  measurements separate parsing, scanning, cache insertion, and position-index
  construction. Large empty caches now use identifier-bit partitions. Reduce
  temporary cache-build memory and complete native chunk construction next;
  opening still exceeds target. Cache-build accumulators restored spare capacity
  in the history memory gate; native chunk construction remains a large cost.
  Native chunks now collect text and style ranges before building attributed
  buffers. Substage clocks still identify styles as their largest measured part.
- Extend native split updates beyond the bounded anchor search. Changes without
  a verified anchor still use one interval and can invalidate most of a document.

## Experiment 4: saved bytes and file safety

The first boundary check uses Bend Base file effects to write and read an exact
16-byte fixture. It includes BOM bytes, CRLF, NUL, emoji bytes, and invalid
UTF-8. Native macOS and JavaScript builds passed. The batch runs both builds and
compares their saved files. File modes are `r` and `w`; the byte effects preserve
bytes without text decoding.
The check reopens the file for read sizes of one, three, and 4,096 bytes. Each
case makes 32 reads, including repeated reads after EOF, and compares all
combined bytes with the exact fixture. All three cases passed in native macOS
and JavaScript builds. Small chunks split the BOM and emoji byte sequences;
one-byte chunks also split CRLF. These reads do not decode text.

The POSIX atomic-replacement experiment writes a sibling temporary file, syncs
it, replaces the destination with rename, then syncs the parent directory.
Six child-process cases stop after creation, partial write, complete write,
file sync, replacement, or successful completion. Exact byte checks find the
old document before replacement and the new document after replacement.
Each case now runs with access modes 0600, 0640, and 0644, for 18 process-exit
cases. The temporary file starts with mode 0600. Before file sync, the host
copies the original regular file's access mode with fchmod. Exact checks confirm
that the saved file keeps its mode before and after replacement. All 18 cases
passed on macOS. This does not check ownership, ACLs, extended attributes, or
read-only files.
A replacement into a directory fails and keeps both the saved document and
temporary bytes unchanged. The macOS check passed and is in the batch.
This checks process exit, not power loss. Linux execution, complete metadata
preservation, concurrent writers, and a Bend save-state contract remain
unverified.

The Bend save-state experiment stores current bytes, confirmed saved bytes,
and a pending snapshot with a unique request identifier. Successful results
update only the saved baseline. Failed or uncertain results keep that baseline.
Only one save may be in progress for a destination. A request made while a save
is pending keeps that request and does not allocate another identifier. After
completion, the next request captures the latest edited bytes. The host must
execute each accepted ticket once and must not retry a completed old ticket.
Late results for older requests keep the newer request unchanged. Edits made
during a save remain dirty. Restoring the saved bytes becomes clean again.
The native state batch passed with one and four threads. Exact state comparisons
check current bytes, saved bytes, identifiers, and pending snapshots. Four laws
cover failure, success, stale results, and one save in progress. This model is not
yet connected to the atomic host or editor.
Save outcomes now distinguish a confirmed old file, an uncertain replacement,
and a confirmed replacement with directory sync. Uncertainty keeps both the
saved baseline and pending ticket, so another writer cannot start. A later
definite result resolves that ticket. Exact checks passed in native builds with
one and four threads, Bun, and Node. A fifth law proves that an uncertain outcome
keeps the complete state.
The pure reconciliation step now checks observed bytes against the pending
snapshot and saved baseline. With confirmed synchronization, matching pending
bytes completes the save; matching old bytes resolves it without advancing the
baseline. Other bytes, failed synchronization, or a stale request identifier
keep the state unchanged. Exact checks passed in native builds with one and four
threads, Bun, and Node. The host must still obtain a stable disk observation and
exclude competing writers; this pure step does not do that work.
The connected save-host experiment now runs the POSIX replacement process from
Bend's Process.run effect. It writes a CRLF/emoji snapshot while the model holds
a later edit, confirms the process exit, reads exact saved bytes back, and checks
the complete resulting state. Native macOS and Bun runs passed. The subprocess
is an experiment boundary, not the final editor save API.
The interrupted host check now connects five controlled process exits to Bend.
Stops after creation, partial write, complete write, or file sync keep the old
disk bytes and resolve the ticket without advancing the saved baseline. A stop
after rename leaves the new disk bytes but keeps the baseline and pending ticket
unchanged because directory sync is not confirmed. Every case checks the exact
current edit, saved baseline, pending snapshot, and disk bytes. Native macOS and
Bun runs passed, and the checks are in the batch. The controlled exit codes name
known stages; arbitrary process failure must remain uncertain.
Two additional laws now prove that unrecognized bytes and an unconfirmed sync
result keep the save state unchanged. The proof gate passed all seven save laws.
The connected check now syncs the regular saved file and parent directory,
then reads exact bytes into Bend reconciliation. Before replacement, the old
baseline remains. After the uncertain rename, matching snapshot bytes resolve
the pending save while preserving the later edit. Native macOS and Bun runs
passed. These are isolated directories without competing writers. The separate
sync and read steps do not provide a stable observation under concurrent changes.
Crash recovery records and concurrent-writer protection remain incomplete.
The POSIX host checks now also reject symbolic-link and directory destinations
before creating a temporary file. An existing pending file blocks another save
without changing either file. Exact checks preserve the original bytes and
target kinds after rejection. The extended process-exit batch passed with
AddressSanitizer and UndefinedBehaviorSanitizer. This checks fixed targets in
an isolated directory, not replacement of a target by another writer between
the host's inspection and rename.
The complete macOS batch passed with the connected save, interrupted save,
reconciliation, and target-rejection checks included. The document memory gate
measured 88,064,000 bytes; the history gate measured 237,207,552 bytes. Native
navigation, input, marked-text composition, and JavaScript checks also passed.
The C atomic-replacement batch and POSIX host round-trip check also passed in
an Ubuntu 24.04 aarch64 container on OrbStack's Linux kernel. GCC compiled the
atomic check with C11 and warnings treated as errors. The repository was mounted
read-only; builds and test files stayed inside the temporary container. This
checks Linux file effects and the POSIX adapter, not the complete Bend Linux
batch or a native Linux text editor.
The save-state checks also passed in Bun and Node. The byte-read check passed
in Bun; Bend 2.0.34 generates a bun:ffi dependency for File.read_bytes, so Node
cannot run that check. The batch reports this limit when Bun is absent, while
still running the native byte check. The POSIX atomic-replacement experiment
also passed with AddressSanitizer and UndefinedBehaviorSanitizer enabled.
The complete batch passed with these checks included. Its document memory gate
measured 88,031,232 bytes, and its history gate measured 236,453,888 bytes.
Native navigation, IME composition, cold document input, and JavaScript adapter
checks also passed. These memory gates are not product idle-memory measurements.

Remaining work: connect original bytes to the document model, define invalid
UTF-8 handling without source loss, connect the tested atomic host to the editor,
implement crash recovery records, and handle external file changes. The isolated
save experiments do not establish complete editor save or recovery behavior.

The recovery-state experiment now compares a validated recorded state with disk
bytes. Matching saved or pending bytes restores the recorded current edit,
uses disk bytes as the saved baseline, and clears the interrupted request.
Unknown disk bytes produce a conflict that retains both complete versions.
Exact checks passed with native one/four-thread builds, Bun, and Node, including
NUL and invalid UTF-8 bytes. Two recovery laws passed. Disk reads are not stable
under competing writers. Record validation and persistence checks are described
below; this model alone does not provide complete crash recovery.
The interrupted-save host check now also passes its actual disk bytes into the
recovery model. All five interruption stages restore the recorded current edit,
select the observed saved baseline, and clear the interrupted request. Native
macOS, Bun, and native Linux Bend runs passed this connected check. The recorded
state remains in the test process; this does not prove recovery after losing
process memory.
The reusable Linux runner now passed the complete batch without interruption.
It used checksum-verified Bend 2.0.34, Clang 18, and Node 18 on Ubuntu 24.04
aarch64. The document memory gate measured 87,371,776 bytes; history measured
236,158,976 bytes. Native file checks and the generated JavaScript editor run
passed. Generated JavaScript byte reads were explicitly omitted because Bun
was absent. The runner is `sh tests/linux.sh`; its image stays cached for later
runs. Native Linux GUI behavior and the x64 image path remain unverified.

src/RecoveryRecord.bend now encodes the complete save state as a versioned ASCII
record: current bytes, saved bytes, next identifier, and the optional pending
snapshot. Decimal byte values preserve NUL and invalid UTF-8 without decoding
them. An FNV-1a checksum covers the record fields. The decoder checks the version,
end marker, checksum, byte range, metadata limit, and pending identifier order.
macOS and Linux native one/four-thread, Bun, and Node checks passed for empty, binary, pending,
and large-identifier states. Every truncated prefix and each single-character
replacement with x in these fixtures was rejected. This checksum detects the
tested accidental corruption; it is not an authentication mechanism. Record
persistence is now checked by a connected restart experiment. One writer process
atomically saves the encoded record and exits with status 79 after confirmed
file and directory sync. A separate reader process loads and validates the
record, reads the saved document, and restores the recorded edit. Both old-file
and pending-snapshot disk cases passed on native macOS, native Linux, and Bun.
The restored current bytes include NUL and invalid UTF-8. No state is passed
between these processes except through the files. This uses a controlled process
exit after a successful record save; it does not establish power-loss behavior.
The small fixtures fit the test's
4,096-byte read bound. Large records, record lookup, and editor integration remain
incomplete.

The journal-interruption check now first saves a valid record, then starts a
separate updater with a later edit and stops its host after creation, partial
write, complete write, file sync, or rename. A third process validates the
selected record and recovers the edit from disk. The first four cases load the
previous complete record; the rename case loads the new complete record.
Incomplete temporary files do not replace the prior record. All five native
macOS, native Linux, and Bun cases passed. The complete macOS and Linux batches
passed with these cases included. macOS document/history memory peaks were
87,998,464 and 236,945,408 bytes; Linux peaks were 87,437,312 and 236,077,056 bytes.
The Linux batch reports its omitted Bun-dependent runtime checks explicitly.
Power loss, large records, competing writers,
record lookup, and editor recovery integration remain incomplete.

## Batch gate

The one-MiB recovery codec check now passes on native macOS and native Linux.
It produces a 6,291,481-byte record and uses about 458 MiB of peak resident
memory. See BENCHMARKS.md for the fixture and measurements. The record exceeds
the disk experiment's input and read bounds. This is evidence for the next
recovery task: reduce record size and memory cost, then check a large record
across separate writer and reader processes. Large-record disk recovery is
still incomplete.

Recovery record version 2 now uses lowercase hexadecimal payloads. It retains
version 1 read support. The same one-MiB fixture produces 4,194,330 bytes,
with about 314 MiB of peak resident memory on macOS and Linux. All byte values,
legacy decoding, and malformed payloads with valid checksums have explicit
checks. This reduces codec cost, but does not yet meet the disk experiment's
bounds or prove large-record restart recovery.
The complete macOS and Linux batches passed with version 2, including the
separate-process restart and five journal interruption cases. The macOS
document/history memory peaks were 88,064,000 and 237,043,712 bytes; Linux
peaks were 87,310,336 and 235,696,128 bytes. Linux still omits the Bun-dependent
JavaScript file-byte runtime checks. A direct hexadecimal output check also
passed on native macOS, native Linux, Bun, and Node.

The native large-record restart check now uses three distinct one-MiB
snapshots. A writer persists the journal and exits; a separate reader loads
the actual source and journal files. Both old-file and completed-save cases
passed on macOS and Linux. The reader checks every recorded field, restores
the current edit, selects the observed saved baseline, and clears the pending
request. The journal contains 6,291,481 bytes. The host's new eight-MiB bound
accepts exactly eight MiB and rejects one extra byte before creating a pending
file. Rejection retains the original document. These checks are now in the
native batch. Large interrupted journal updates, large JavaScript records,
power loss, record lookup, competing writers, and editor integration remain
incomplete. Codec memory cost remains high; it is not a product idle-memory
measurement.
Both complete batches passed with the large restart and host input-limit
checks included. macOS document/history memory peaks were 88,047,616 and
236,748,800 bytes; Linux peaks were 87,420,928 and 235,438,080 bytes. These
remain core memory-gate results. The large recovery check runs natively;
Linux still reports its omitted Bun-dependent runtime checks.

Large interrupted journal updates now pass all five stages on native macOS
and native Linux. The fixtures contain three distinct one-MiB snapshots.
Separate initial writer, updater, and reader processes use only disk files
to transfer state. Before rename, recovery restores the prior complete edit.
After rename, it restores the later complete edit. Every recorded field and
the restored saved baseline are checked. The new cases are in the native
batch. This step ran the ten new platform cases and the Bend proof gate;
the prior complete-batch result still applies to the unchanged core. Power
loss, large JavaScript records, competing writers, record lookup, and editor
integration remain incomplete.

External file changes across restart now have connected one-MiB checks.
A separate process changes and syncs the saved document after the writer
stops. The recovery reader must retain the complete recorded state and disk
version as a conflict. Two cases passed on native macOS and native Linux:
disk bytes matching the current edit, and a fourth distinct disk version.
Neither matches the recorded saved or pending snapshot. Exact file comparisons
confirm that recovery changes neither source nor journal and creates no pending
replacement. The four new platform cases, Bend proof gate, and script syntax
checks passed. The cases are in the native batch. Simultaneous writers,
file watching, conflict-resolution UI, record lookup, power loss, large
JavaScript records, and editor recovery integration remain incomplete.

The one-MiB version 2 codec now passes on JavaScript. The first Bun and Node
runs failed with stack overflow in byte validation. Encoding, decoding, record
splitting, and byte comparison now use accumulators and tail calls on the
version 2 path. Native bytes and checksums are unchanged. The proof gate and
complete macOS and Linux batches passed after this core change. The JavaScript
batch now includes the one-MiB round trip. macOS Bun 1.3.11, macOS Node 22.22.3,
and Linux Node 18 passed. Native macOS and Linux large restart, interruption,
and conflict cases also passed. macOS document/history memory peaks were
88,080,384 and 237,371,392 bytes; Linux peaks were 87,564,288 and 236,756,992
bytes. These remain core memory gates, not codec or product idle-memory
measurements. The measured JavaScript codec memory cost remains high; see
BENCHMARKS.md. Large JavaScript disk recovery and large legacy JavaScript
decoding remain unverified. Editor integration, record lookup, power loss,
simultaneous writers, and the remaining product requirements are incomplete.

Large JavaScript disk recovery now passes all nine cases with Bun 1.3.11 on
macOS: two restart states, five journal interruption stages, and two conflicts.
The tests use separate processes and actual disk files with the same three
distinct one-MiB snapshots. The conflict driver now accepts an optional runtime;
its two native cases passed again. The new JavaScript cases run in the Bun
batch. Node still runs the codec because Bend 2.0.34 file-byte effects require
Bun. The Linux runner now includes Bun 1.3.11 from a digest-pinned image and
checks its version during the build. The complete Ubuntu 24.04 aarch64 batch
passed with all nine large JavaScript disk cases, small restart and journal
checks, byte preservation, connected saves, interrupted saves, and host checks
enabled. The runner no longer omits those Bun-dependent checks. Native
document/history memory peaks were 87,318,528 and 236,220,416 bytes; these are
core memory gates. Linux native GUI behavior, the x64 image, record lookup,
editor recovery integration, power loss, simultaneous writers, and the remaining
product requirements are incomplete.

The real directory listing limit now has a connected stress check. A new
isolated root contains 2,200 directories with 250-byte names. Its complete
listing would exceed one MiB. The host returns failure without END and keeps
partial output within the bound. Bend reports the failed scan instead of
accepting a partial catalog. Native and Bun cases passed on macOS and Linux.
Every exact candidate name and directory type remains intact after failure.
The tests use the default host limit and are in the batch. No production code
changed. Large successful catalogs, streaming enumeration, concurrent changes,
application storage, nonfatal UI errors, editor integration, and the remaining
product requirements are incomplete.

The read-only recovery directory host now lists candidate directories and
unsupported entries with hexadecimal names and a complete-listing marker.
Bounded reads open one child under the root and reject symbolic links, unsafe
names, non-files, and records above eight MiB. Host checks passed on macOS and
Linux for empty and complete listings, root failures, unsupported entries,
missing records, newline-bearing names, exact binary reads, and the eight-MiB
read boundary. Linux checks non-UTF-8 names; the macOS fixture reports the
filesystem's verified rejection of their creation. The new host checks are in
the batch. C does not validate record contents. Bend scan integration,
invalid-file reports, listing-limit stress checks, concurrent directory changes,
application journal lookup, editor integration, and the remaining product
requirements are incomplete.

src/RecoveryScan.bend now connects host enumeration and candidate reads to Bend
record validation. Accepted entries retain origin names. Rejected candidates
retain names and distinct unsupported-type, read-failure, and invalid-record
reasons. Root failures and incomplete listings fail the scan instead of returning
an empty catalog. Accepted entries feed exact-identity lookup while the caller
retains the full catalog. The mixed fixture checks two valid records, five
rejected candidates, a copied duplicate, and a failed root. Unique and duplicate
scans passed on native macOS, macOS Bun, native Linux, and Linux Bun. Both valid
record states and all rejection names/reasons are checked. Exact comparisons
confirm that scanning does not change any record or remove unsupported entries.
The new retention laws passed the proof gate. New cases are in the native and
Bun batch. Listing-limit stress, large scans, concurrent directory changes,
application storage, nonfatal UI errors, editor integration, and the remaining
product requirements are incomplete.

src/RecoveryEntry.bend now provides a document identity prototype. It wraps the
checked state record with a nonempty opaque byte identity and covers both with
an outer checksum. Matching saved bytes alone cannot associate an entry with
a document. A wrong identity retains the complete entry and disk bytes;
matching identities delegate to the existing recovery and conflict rules.
The small fixture includes two identities with identical empty saved baselines.
Native one/four-thread, Bun, and Node checks passed on macOS and Linux. Tests
reject empty or invalid identities, altered identity fields, every truncated
prefix, appended text, bare state records, and invalid inner checksums. The new
mismatch law passed the Bend proof gate. These checks are in the batch.
Host identity assignment, filesystem lookup, large wrapper measurements,
migration, and editor integration remain incomplete.

The identity wrapper now passes connected process-restart checks with three
distinct one-MiB snapshots and two actual files with identical saved bytes.
The writer syncs the files, saves the wrapper through the atomic host, and
exits. Fresh readers validate the persisted identity and complete state. The
owner restores its edit; the other file retains both versions as WrongDocument.
Exact file comparisons confirm that recovery changes neither source file nor
journal. Both cases passed on native macOS, macOS Bun, native Linux, and Linux
Bun. The wrapped journal has 6,291,504 bytes. The eight new platform/runtime
cases and proof gate passed. Native and Bun batch paths now include the cases.
The fixture uses fixed identities; stable host assignment, filesystem lookup,
migration, wrapper performance, editor integration, simultaneous writers,
power loss, and the remaining product requirements are incomplete.

The entry restart fixture now uses a POSIX PATH1 identity provider instead of
fixed a/b keys. The host resolves existing readable regular-file paths and
returns opaque identity bytes. Its checks passed on macOS and Linux for
relative paths, symbolic-link aliases, parent path components, Unicode names
with spaces, distinct destinations with equal bytes, and identity stability
after atomic replacement. Directory, missing-file, and FIFO targets are
rejected without output. Each connected writer and reader obtains identities
from the actual files. Both one-MiB owner and wrong-document cases passed on
native macOS, macOS Bun, native Linux, and Linux Bun. The proof gate, script
syntax checks, and diff checks passed. New cases are in the batch. Rename/move
handling, case aliases, Unicode path normalization, hard-link policy,
concurrent path changes, unsaved identities, application journal lookup,
editor integration, and the remaining product requirements are incomplete.

src/RecoveryLookup.bend now selects validated entries by exact document identity.
Unique selection requires one match. Duplicate owners remain Ambiguous with
all matching entries retained, including identical duplicates. Invalid requests
retain the query and candidates. Missing means no match in the validated list,
not absent disk data. Checks cover ordering, unrelated documents with equal
saved bytes, invalid requests, duplicate versions, and a 65,536-entry traversal.
Native one/four-thread, Bun, and Node checks passed on macOS and Linux. The
duplicate and invalid-request laws passed. The persisted one-MiB fixture now
checks selection before its existing recovery guard; native and Bun cases
passed on both platforms. New checks are in the batch. Filesystem enumeration,
invalid-file reporting, duplicate resolution, application journal lookup,
rename/move migration, unsaved identities, editor integration, and the remaining
product requirements are incomplete.

The path identity batch now checks case and Unicode spellings using the
filesystem's actual alias behavior. Both pairs are aliases on the tested macOS
filesystem and distinct names on Linux. Alias identities match; distinct names
with equal bytes retain separate identities. Hard-link destinations also keep
separate PATH1 identities. Atomic replacement leaves both identities stable,
retains the hard link's exact old bytes, and writes the exact new bytes at the
selected destination. All macOS and Linux path cases passed. No core path
normalization was added. The new cases are in the existing batch. Script syntax
and diff checks passed. Other filesystem variants, rename/move migration,
concurrent path changes, unsaved identities, application journal lookup,
editor integration, and the remaining product requirements are incomplete.

## Save As and uncertain publication

The application now owns an Editing, Saving, or Uncertain workspace. Save As
resolves the target and publishes a new file without replacing an existing
file. A confirmed result adopts the new destination. An uncertain result keeps
the target, ticket, captured bytes, current edits, and undo history. Save and
Close stay blocked until a confirmed observation resolves the transaction.

Recheck Save As is connected to the macOS button and the terminal `.recheck`
command. It checks the retained destination without publishing again. Focused
macOS and Linux observation batches passed. Terminal application checks passed
for adoption, later Save, mismatched bytes, and a missing target. The latest
complete application batches passed on macOS and Linux aarch64. The native
Recheck button test also passed for matching, different, and missing files.
The automated native Save As dialog confirmation
test remains unsuccessful. These results do not establish Windows support or
the complete product target. See SAVE_AS_EXPERIMENT.md and
NEW_FILE_OBSERVATION.md for the test scope and limits.

## Return and list continuation

Return is now a Bend-owned command in the formatted editor. It continues
top-level unordered items with `-`, `*`, or `+`, keeps exact prefix spacing,
and exits empty items without removing their existing line ending. Other
selections and fenced code use the ordinary newline edit. The incoming
formatted selection is mapped once, before the accepted source edit. Undo
retains that selected snapshot.

Native Bend, Node, and Bun command checks passed on macOS, including a
65,536-scalar item. The first macOS and Linux command batches passed. Expanded
spacing, empty-CRLF, middle-of-item, fence, and hidden-inline-mark command
checks passed on macOS and Linux aarch64. A native macOS Return
event check and the marked-text bypass host check passed. Return, Undo, and
Redo retain an uncertain Save As transaction in the workspace checks.

The standard proof and history-memory gates passed. Source replacement, block
comparison, and full scene-map assembly use tail loops where the long-line
check found JavaScript stack limits. The first Return implementation scans
source lines and presents the full accepted source; it does not establish the
16 ms product target. Full application batches passed on macOS and Linux
aarch64. The extended command checks passed separately and are now in the
permanent list batch; its updated macOS and Linux aarch64 runs passed, as did
the standard proof gate. Details and the
remaining checks are in LIST_CONTINUATION.md.

The baseline Return core medians are 24 ms for 100 KiB and 440 ms for 1 MiB.
src/IndexedReturn.bend is a separate planner prototype. It uses cached block
offsets and scans the active block and predecessor context. It does not build
the preceding source. Differential checks passed every selection pair in the
initial fixtures in native Bend, Node, and Bun on macOS and Linux aarch64.
Closed-fence EOF cases with LF and CRLF also passed on macOS. Architect review
found no code defect. The planner is now connected to both Return command paths.
The connected macOS and Linux aarch64 batches, history-memory checks, and
standard proof gates passed. The repeat timing run passed; both core medians
were 0 ms at the one-millisecond clock resolution. This does not establish
native frame latency. The legacy
planner remains the differential reference. A single large
active or preceding block can still require a large scan.

The native Return benchmark passed all six batches: 100 KiB, 1 MiB, and a
65,538-byte item, each with stage clocks disabled and enabled. The measured
uninstrumented medians through layout and display were 37.722, 540.832, and
56.362 ms. Source and chunk delivery dominate the many-block case; the final
display call is small. These checks do not measure physical screen delivery.
Return now uses accepted source ranges and ordered selection/edit scene
patches. Pure replay and native stale-selection checks passed in both command
paths. Focused platform, workspace, memory, and proof gates passed. Full
application gates passed on macOS and Linux aarch64 with the final permanent
Return batch. The repeat six-case timing batch passed. Uninstrumented medians
are now 2.002 ms for 100 KiB and 16.872 ms for 1 MiB. The long item regressed
to 73.811 ms, with 22.970 ms in its instrumented chunk-update stage. Matching
text and attribute edges are now retained within native preview patches that
have no pending native input edit. Source, scene, history, Unicode, and
style-only checks passed, as did complete platform gates after the source
move. The isolated six-case repeat passed all 120 samples. Every instrumented
Return inserted only three preview units. Long-item chunk-update time was
1.466 ms, but total timing evidence is mixed: the long uninstrumented median
was 81.481 ms and the instrumented median was 47.596 ms. The additional
outside-clock reference check differs from the old benchmark. No causal
overall speed improvement is established. The 1 MiB uninstrumented p95 was
26.703 ms, above the product target. The next experiment will profile work
before native presentation with unchanged session ownership and exact checks.
Details and all samples are in BENCHMARKS.md.

Run `sh tests/check.sh`. It checks Bend laws, builds native and JavaScript
programs, and runs cursor, text-position, direct-state, document, and adapter
checks, plus the retained-memory gate. On macOS it also runs the native window
event loop without manual input.
It does not prove full CommonMark behavior, keyboard IME translation, or the
product performance budget.

Keep important rules in LAWS.bend. Run `bend PROOF.bend` before each commit.
Commit each completed feature or fix after its checks pass, as requested by
the user. Keep incomplete experiments separate from completed changes.

## Source layout

Application Bend, C, and JavaScript files are in `src/`. Tests stay in `tests/`.
Project documents stay at the root. `LAWS.bend` and `PROOF.bend` are intentional
root exceptions; the proof command remains `bend PROOF.bend`. The move kept
all 83 source-file contents unchanged. Root proof imports, test imports, C
includes, JavaScript fixture reads, build scripts, and current document paths
use the new directory. All 1,240 local Bend and foreign imports resolved.
The standard proof, macOS host, Node/Bun host, POSIX syntax, application builds,
and focused native document checks passed. Complete application gates then
passed on macOS and Linux aarch64 from this layout. The architect found no
remaining path correction. The earlier pre-move native source assertion did
not repeat in focused warm/cold checks or the new full macOS gate. Its cause
remains unknown; the diagnostic and failure record stay in place.
