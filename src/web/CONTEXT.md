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
