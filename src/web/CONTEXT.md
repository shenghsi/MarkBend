# Desktop editor language

The source record retains original Markdown text, its BOM, and its line endings.
The edit surface is CodeMirror's normalized text document. A source patch maps
edit-surface positions to the source record. CodeMirror owns input and history.
Undo restores both the edit surface and its exact source record.
New ordinary line breaks use the first line ending in the source record, or LF
when the record has none. Bend Return can supply the current line's ending.
Existing line endings remain unchanged. File commands defer during composition.

Live preview uses decorations and widgets in the edit surface. A widget reveals
its source when selected. Source mode removes preview decorations. A rendered
widget is never the saved document. The desktop host owns native file effects.
The Bend command module supplies source edits, not another history.
MathJax supplies formula rendering. The micromark math extension supplies formula
source ranges. Selected ranges include boundary positions and all selections.
HTML preview frames have no scripts, same-origin access, or external resources.
Removed widgets discard pending renderer results. Source mode retains history.

A table cell has a single-line raw Markdown edit surface. Its CodeMirror view
has no history. Each accepted cell edit patches the source record through the
outer CodeMirror view. Outer Undo and Redo synchronize the cell edit surface.
Active cell ranges map through source patches, including typed edge spaces.
Unescaped pipes become escaped pipes. An odd final backslash directly before a
column delimiter gets a second backslash. Existing cell padding stays intact.
Table source reveals the complete table. File and display commands defer during
cell composition. Removing a table destroys its cell edit surface.

Table structure commands validate a patch plan before ending the cell edit.
Column commands patch all rows in one history transaction. New rows use the
source record's first line ending. Existing slot text stays unchanged except
for the requested slot or alignment token. Empty edge cells and one-column
tables get the outer delimiters needed for valid GFM. New headers use Column.
Nested-table previews omit container prefixes only while rendering. Their
source retains each prefix. Structure commands inside containers stay disabled.

Omitted cells have virtual ranges at the source row's end. Selecting them does
not change source. First input adds only the slots needed to reach that column,
and validates the new ranges before acceptance. History retains exact active
cell ranges and maps them through later changes. Replacing a whole source row
ends its cell edit, so an old cell cannot append to replacement text.

Search uses the normalized Markdown source, including hidden widget source.
Original BOM and line-ending spelling stay in the source record. Replace
commands use the outer history. Every search selection and replacement defers
during outer or cell composition. Find ends cell editing before selecting source.
The outline uses parsed heading ranges and text labels. Heading navigation adds
no history event. The outline refreshes when text or the syntax tree changes.

List markers use parser ranges. Ordered markers retain their number and spelling.
Selecting any part of a list item, including continuation lines, reveals its
marks. Task checkboxes validate the current marker and change one character
through outer history. They defer during outer or cell composition and reject
read-only state. Quote lines have one border with a nested depth. Marker
rendering and focus never change source or create history.

Formatting controls send source edits through outer history. Parsed delimiter
ranges supply removal patches. New nonempty inline spans must pass the Markdown
parser before acceptance. Code uses a longer backtick run and CommonMark padding.
Heading conversion retains the text line's ending and removes the underline
line when needed. Commands require one selection. Inline commands require one
line; headings require a top-level line. The next line is excluded when a
selection ends at its start. Active cell edits and composition defer formatting.
Commands do not use a partial syntax tree to guess the selected block.

Link controls capture one source range and a document generation. Every source
change or document reset invalidates that capture, even after Undo or Redo.
Apply and Remove recheck source identity, generation, and input guards. Apply
patches only changed fields, so untouched raw label, destination, title, and
separator spelling remain intact. Both package parsers validate the complete
link before acceptance. Destination checks include Markdown escape/entity
decoding. Raw angles require URL encoding. Multiline fields remain source edits;
existing multiline separators can stay unchanged. Cancel adds no transaction.
Form Escape defers during composition. Reference removal retains the label and
shared definition; reference updates remain source edits. Links do not navigate.

Theme is a presentation preference: System, Light, or Dark. It changes the root
palette without editor transactions or state replacement. Active outer and cell
composition, selection, source record, and history stay intact. The preference
is local to the app; unavailable storage does not prevent theme changes.
System follows the operating-system color preference. Code tokens use palette
classes. Isolated HTML and Mermaid retain a light canvas for authored colors.

Return uses the Bend command for flat list items and ordinary text. Parsed
nested lists, quote containers, and list continuation lines use CodeMirror's
Markdown command. Empty nested items exit one level. New task items are unchecked.
Ordered continuation can renumber consecutive later siblings in the same edit.
The package route uses the source record's first line ending; Bend retains its
current-line ending rule. Existing endings and the BOM remain intact. Code,
HTML, table source, unavailable syntax, and rejected package commands use plain
Return. Each accepted Return uses outer history. Composition, read-only state,
and multiple selections reject the command before route selection.

Recovery copies contain exact source, a display label, and a revision. A single
serialized queue captures source and dirty state together. It waits 500 ms after
input, then sends the latest capture. Continuous input starts a checkpoint after
at most 2 seconds of scheduling delay; disk completion has no such guarantee.
A failed capture stays pending; a newer
capture takes its place. Retry gets a higher revision. Confirmed Save clears a
copy only when the current source equals the saved baseline and Save is certain.
Later edits and uncertain Save retain a dirty copy. Checkpoints never dispatch
editor transactions. File transitions wait for the required recovery result.

The desktop host owns recovery files and session leases. Each renderer start
gets a new token and retains its predecessor's copy. Startup offers inactive
session copies. Restore reads a validated copy before discarding current source,
then opens an untitled unsaved document with a new history and no file baseline.
It keeps the recovery copy and original file. Labels are display text only.
Checkpoint failures show Retry recovery; failed Close keeps the window open.
Recovery starts from the last confirmed checkpoint, not an unconfirmed keystroke.

File checks compare disk bytes with the host's saved baseline. They never change
source or history. Checks do not overlap. Document transitions invalidate pending
results and errors. Checks defer during file commands and outer or cell composition.
Reload waits for discard confirmation and recovery acknowledgment before reading.
A valid read starts a new history. Cancel and failed reads retain source and
baseline. Uncertain Save blocks Reload and Save As until Check Save succeeds.

Image preview uses parser source ranges and package-decoded destinations, titles,
and alt text. Reference-definition edits refresh their images. File transitions
refresh image context, even when a Save retains the same path. Selecting an image
reveals source and never navigates. Loading and failure show alt text. Removed
widgets ignore pending results and revoke Blob URLs. Source and history stay intact.
Local and data images have an 8 MiB byte limit and PNG, JPEG, GIF, or WebP signature
checks. This byte limit does not bound decoded dimensions or memory. Local paths
decode percent escapes once and resolve against the host document directory.
Untitled relative paths fail with an edit hint. Local SVG remains open.
HTTPS images use the browser's image loader with no referrer; they
make network requests and expose the client address. Remote images can use other
browser-supported formats, including SVG, and have no app byte or dimension limit.
The native CSP restricts remote image resources to HTTPS; the app does not check
each redirect destination itself. HTML and table image rules remain separate.

Image controls share the link form and source-patch commands with an explicit
image kind. Insert, Apply, and Remove use the outer history. Remove retains the
raw Markdown alt label and keeps shared reference definitions. Reference updates
remain source edits. Apply retains unchanged field spelling and rechecks the
source capture and input guards. Choose Image fills an encoded absolute path;
it does not edit source or copy an asset. Each picker request has a token. Cancel,
reopening, field input, changed source, and composition reject late results.
Selected path punctuation encodes once; native separators and drive spelling
remain intact. Windows drive and UNC host checks still need a Windows run.

The document language uses CodeMirror's YAML front matter wrapper around Markdown.
Metadata begins only at document start and uses exact three-dash lines. The
package does not accept a three-dot line or trailing spaces as its closing mark.
Closed metadata has a literal text preview. Selecting it reveals highlighted
YAML source. Empty metadata is valid. Unclosed metadata stays source through the
document end. Metadata supplies no app configuration and is never evaluated.
Preview, outline, and image reference-definition collection exclude metadata.
Package ranges retain body offsets. Formatting and link/image controls reject
metadata. Return inserts a plain newline there, including unclosed YAML lists.
All metadata edits and mode changes keep the exact source record and outer history.

Footnotes use the upstream GFM footnote package and UTF-16 source ranges. Resolved
references get numbers in first-use order. Repeated references share a number;
the first duplicate definition is accepted. Missing references retain source
marks. Selecting a reference or definition reveals source without a history edit.
Definitions retain container prefixes and continuation lines in the source record.
Definition headings do not enter the outline. Controls reject selections that
touch definition source or cross a reference. Return in definitions is plain.
Definition preview renders text and formatting with no active links or resources.
HTML and math stay literal; images show alt text. References inside definitions
are not numbered. Footnote insertion and navigation remain open. The shared
model parses the full Markdown body after source edits when footnote syntax is
present. Its large-document timing is not yet measured.
