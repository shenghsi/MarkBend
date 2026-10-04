# Desktop editor language

The source record retains original Markdown text, its BOM, and its line endings.
The edit surface is CodeMirror's normalized text document. A source patch maps
edit-surface positions to the source record. CodeMirror owns input and history.
Undo restores both the edit surface and its exact source record.
New ordinary line breaks use the first line ending in the source record, or LF
when the record has none. Bend Return can supply the current line's ending.
Existing line endings remain unchanged. File commands defer during composition.

The main app uses document tabs for its file workflow. A tab owns one editor
state, path, baseline, Save uncertainty,
Source mode, scroll snapshot, and recovery queue reference. IDs cannot be reused.
Accepted switches end cell editing, call the form-invalidation hook, retain an
unlocked state, and restore the target state and its scroll effect. Guards run
before these actions. Scroll effects add no source or history edit. Removal
requires another active tab; the caller must confirm host recovery clearance and
retirement first. Tab labels use literal text. Arrow keys move focus; normal
button activation requests a document switch. New, Open, file drop, and Restore
add tabs and retain the other documents. Every host command and image read uses
its captured document ID. Close confirms only its target, flushes its queue,
activates another live document, and clears recovery before host retirement.
Failed retirement retains the document and rebuilds its recovery copy. Closing
the last tab creates a replacement first. Native scroll acceptance remains open.

Live preview uses decorations and widgets in the edit surface. A widget reveals
its source when selected. Source mode removes preview decorations. A rendered
widget is never the saved document. The desktop host owns native file effects.
The Bend command module supplies source edits, not another history.
CI builds one editor artifact with the tested Bend compiler. Its checkout SHA
and complete file hashes must match before each native platform build. Windows
embeds the same generated commands and requires no native Bend compiler. Build
evidence does not establish platform input or rendering acceptance.
MathJax supplies formula rendering. The micromark math extension supplies formula
source ranges. Selected ranges include boundary positions and all selections.
HTML preview frames have no scripts, same-origin access, or external resources.
Removed widgets discard pending renderer results. Source mode retains history.

Selection-only preview updates reuse unchanged decorations. An overlap group
contains item source, hidden marks, physical line starts, and list owner ranges.
Touching groups merge. A changed group uses the full decoration construction,
so revealing a replacement also restores its nested marks. All selections and
both boundaries take part. The group index is built on first selection update.
Source, syntax tree, image context, or table-cell changes discard it and use the
full construction. Large selection changes can also use the full construction.
The full rebuild remains the integration-test reference. This reduces measured
selection-state work; it does not establish typing or screen-frame speed.

Preview analysis reuses top-level parser blocks only when the tree identity and
exact physical-line envelope match. The envelope includes marker-label text and
quote lines outside the exact block span. Its text limit is 65,536 UTF-16 units.
Cache entries contain plain item data and a source anchor, with no editor state,
source document, or widget. A moved block maps item, hidden-mark, marker, and
list-owner ranges together. Unchanged anchors retain item objects. Footnote
definition envelopes and image-containing blocks use fresh analysis. The global
footnote overlay and image-definition resolution stay current. Mounted Markdown
body navigation retains metadata boundaries; unsupported tree nodes use the full
collector. The full traversal remains the item and decoration reference.
Edits still enumerate all top-level blocks and assemble the complete decoration set.

Decoration construction reuses raw ranges for immutable preview items. A weak
item key stores only ranges and selection, table-editing, and physical-line
conditions. Shifted items get new widgets with current source coordinates.
Global replacement suppression and range sorting still run on each construction.
The reference builder bypasses this cache. Small-document reparsing can replace
unchanged items, so reuse is not guaranteed after every source edit. This lowers
some measured construction costs; it does not establish the 16 ms frame target.

A table cell has a single-line raw Markdown edit surface. Its CodeMirror view
has no history. Each accepted cell edit patches the source record through the
outer CodeMirror view. Outer Undo and Redo synchronize the cell edit surface.
Active cell ranges map through source patches, including typed edge spaces.
Unescaped pipes become escaped pipes. An odd final backslash directly before a
column delimiter gets a second backslash. Existing cell padding stays intact.
Table source reveals the complete table. File and display commands defer during
cell composition. Removing a table destroys its cell edit surface.

Table previews use the upstream GFM and math tree. MathJax renders inline
formulas in headers and cells. Package values retain TeX backslashes, including
escaped pipes; package ranges retain literal source on failure. Active cells
show raw source. Opening a cell or removing a preview cancels formula results.
Rendering creates no source or history transaction. Image alt text keeps math
literal. Table reference collection retains accepted package definition records,
including titles in containers; the first definition wins. This adds a body
parse to reference collection and does not establish typing performance.
Chrome formula drawing, cell input, Enter, Undo, and Redo have a UI check.
Native table-formula display and Windows/Linux acceptance remain open.

Table images use package image tokens, document reference definitions, and the
same image loader as ordinary previews. Sanitized table HTML contains only
generated image slots; it contains no image URLs or link actions. Missing image
references stay literal. Active cells show raw source. Opening a cell, replacing
inactive cells, removing a table, and Source mode cancel its image mounts and
release Blob URLs. Pending results cannot replace the cell edit surface.
Image loads use the captured document ID and path. Metadata definitions are
excluded. A weak document-text key retains one lazily parsed reference environment
per body boundary; it retains no editor state. Source edits conservatively refresh
all tables, including unrelated cells. This is a correctness rule, not a speed
improvement. Chrome data-image decode, cell editing, and Undo/Redo have a UI check.
Native local-image display and Windows/Linux table-image checks remain open.

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
Hidden outline content is deferred. Showing it sends a presentation refresh with
no source or history edit. Heading labels use an exact-source cache with at most
1024 entries; each cached heading has at most 4096 UTF-16 units.

List markers use parser ranges. Ordered markers retain their number and spelling.
Selecting any part of a list item, including continuation lines, reveals its
marks. Task checkboxes validate the current marker and change one character
through outer history. They defer during outer or cell composition and reject
read-only state. Quote lines have one border with a nested depth. Marker
rendering and focus never change source or create history.

Formatting controls send source edits through outer history. Parsed delimiter
ranges supply removal patches. Strikethrough uses the same command path as Bold
and Italic. New strike spans use two tildes; removal uses parsed marker ranges
and retains nested formatting. Code text rejects strike marks. The toolbar keeps
the edit-surface selection. Empty selections put the caret between new marks.
New nonempty inline spans must pass the Markdown
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
session copies. Restore reads a validated copy, then adds an untitled unsaved
tab with a new history and no file baseline. Existing tabs stay intact.
It keeps the recovery copy and original file. Labels are display text only.
Checkpoint failures show Retry recovery; failed Close keeps the window open.
Startup obtains all live host documents and replacement recovery sessions in
one host operation. It needs no document-0 assumption. Baselines start new
histories; predecessor dirty copies remain available through Recovery. Input
stays locked after failed startup until Retry succeeds. Quit captures and flushes
every tab. Window Close clears every current copy; a partial failure rebuilds
the retained dirty copies before the user can retry.
Recovery starts from the last confirmed checkpoint, not an unconfirmed keystroke.

Application Quit uses a host request token. Busy file commands and outer or cell
composition reject the request with a retry message. Input locks before discard
confirmation. Cancel and errors restore input. Confirmed Quit captures the latest
exact source and awaits recovery before it approves host exit. It keeps the copy.
An approved request keeps input locked until exit. Listener startup buffers old
events until the host returns a current pending token. Neither Quit nor Cancel
adds source or history edits. Window Close remains a separate clear policy.

File checks compare disk bytes with the host's saved baseline. They never change
source or history. Checks do not overlap. Document transitions invalidate pending
results and errors. Checks defer during file commands and outer or cell composition.
Reload waits for discard confirmation and recovery acknowledgment before reading.
A valid read starts a new history. Cancel and failed reads retain source and
baseline. Uncertain Save blocks Reload and Save As until Check Save succeeds.

Native file drop accepts one Markdown or text file with an md, markdown, or txt
extension, without changing path spelling. It uses the shared Open load path.
Busy commands and outer, cell, or form composition prevent tab creation.
Recovery acknowledgment precedes the host read. Rejected drops and failed
recovery or reads retain existing tabs, source, and history. A valid read adds a
tab with a new history and updates image context and file checks. The extension
only selects this workflow; the host still validates file bytes. A drop hint is
presentation only. Page disposal removes the listener, including late registration,
and ignores later events. Native OS drop acceptance remains unverified.

Desktop New, Open, and Save As shortcuts use the existing toolbar command route.
The platform modifier is Command on macOS and Control on Windows/Linux. Only
these three shortcuts use document capture, because table widgets stop bubbling
keys. Plain Save remains the editor or table command. Outer, cell, and form
composition prevent file shortcuts. Repeat keys add no command. Page disposal
removes the listener. Native menu interception still needs a platform check.

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
each redirect destination itself. Table images use the same resource rules.
HTML frames keep their separate resource rules.

Image controls share the link form and source-patch commands with an explicit
image kind. Insert, Apply, and Remove use the outer history. Remove retains the
raw Markdown alt label and keeps shared reference definitions. Reference updates
remain source edits. Apply retains unchanged field spelling and rechecks the
source capture and input guards. Choose Image fills an encoded absolute path;
it does not edit source or copy an asset. Each picker request has a token. Cancel,
reopening, field input, changed source, and composition reject late results.
Selected path punctuation encodes once; native separators and drive spelling
remain intact. Windows drive and UNC host checks still need a Windows run.

Image-only clipboard paste inserts one PNG, JPEG, GIF, or WebP as inline data
source. Plain text, HTML, and URI lists retain ordinary CodeMirror paste.
Encoded source must fit the 8 MiB document limit. Package image insertion checks
protect source contexts. The request captures source, selection, tab identity,
path, and generation; later edits, Undo, switches, or presentation effects cancel
it. Busy, composition, and read-only guards run again before dispatch. Accepted
paste adds one outer history edit and no file or baseline effect. Rejected
image-only paste is consumed so empty-text fallback cannot delete a selection.
Table cells accept raster paste through their filtered child edit and outer
history. The accepted package reference context protects code, math, links,
HTML, and existing image syntax. The inserted image must match its exact cell
range. Omitted-cell padding participates in the encoded size check before a
proposed table parse, then the complete filtered outer patch is checked again.
Cell end, switches, source changes, Undo, and selection changes cancel reads.
Cell and outer pastes share result and status request order. Later
requests supersede older result and status publication. Inline data works in an
untitled document and remains in Save and recovery. Asset-folder copying remains
open; this does not supply that workflow. Native clipboard acceptance remains open.
Chrome binary clipboard paste, 32 by 32 PNG decode, Undo, and source-mode Redo
have a UI check. The desktop WebView and Windows/Linux paths remain unverified.
The same Chrome checks cover paste into a selected table cell and Enter.

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
HTML stays literal; images show alt text. MathJax renders inline and block math
inside definitions with the app's bundled fonts. Formula failure retains its
literal text and an edit hint. Definition removal cancels pending results. SVG
has no link or resource actions; only MathJax supplies formula layout styles.
Rendering adds no source or history transaction. References inside definitions
are not numbered. Footnote inserts a new reference after selected text and adds
a top-level definition at document end in one history edit. Existing text,
trailing whitespace, BOM, and line endings stay intact. The package must accept
both additions before dispatch. Labels avoid existing definitions and missing
references. New note text is selected for replacement. Go to Footnote selects
the accepted definition, or its first reference when used inside a definition.
Insertion requires one text line and rejects unsupported source blocks.
Navigation adds no source edit. Both commands defer during composition and cell
editing and reject read-only state and multiple selections. The shared
model caches upstream plain-text ranges. Unicode letters, numbers, combining
marks, spaces, and tabs can map cached notes inside eligible plain text. Both neighboring
code points must stay complete and unchanged across every change, including
insertions inside a surrogate pair. At least one neighbor must not be an ASCII
digit; deleting letters between digits can create an ordered-list marker.
Each change stays on one physical line and retains a word character on each
side. Separator edits cannot remove both guarded neighbors or make a line blank.
Punctuation and Markdown delimiter edits use full parsing. Ampersand text and link/image descendants
use full parsing because an edit can complete an entity or change reference-link
resolution. Their nested footnote references still take part in numbering.
Definition AST and
all source ranges map together. Protected source and other edits use the full
upstream body parse. The fresh-parser oracle bypasses the cache in checks.
The optional editor-state benchmark shows substantial fallback cost. It does
not measure native input, DOM layout, memory, or a screen frame; the 16 ms product
target remains unmet. The optional Unicode benchmark compares source-mode state
updates with separate fresh parses. It does not use native composition events.

Print / PDF opens a separate complete-document projection from the captured
editor state, document ID, path, and title. It does not use the virtualized editor
DOM. Source, history, selection, baselines, and recovery remain unchanged.
The upstream GFM and math packages supply the body tree. The document-language
package supplies the metadata boundary; metadata prints as literal text.
Footnotes keep their preview resource rules. Math and LaTeX fences use MathJax.
Print waits for formula, diagram, code, frame, and image results. A 15-second
timeout or failure retains visible source and permits explicit Print with warnings.
Inline HTML prints as literal source with a warning. Block HTML uses an isolated
fixed-height frame and warns about clipping. Its printed pagination is unverified.
Generated links have no actions. Mermaid styles stay inside SVG image resources.
Closing cancels result publication and releases image URLs and timers.
Local images read during preparation with the captured document ID and path;
the host checks changes during that read. Image bytes are not part of the captured
Markdown state. A retired ID fails without selecting another document. HTTPS
images use the browser loader and make network requests. Paper has its own light
palette in either app theme. Print invokes the system dialog; PDF availability
depends on that dialog. Native Print acceptance and direct PDF files remain open.

Export PNG captures the settled paper at its displayed width and full height.
It uses one pixel per CSS pixel, a white canvas, system fonts, and the bundled
formula glyphs. The html-to-image package supplies DOM rasterization. Before
capture, each image becomes embedded raster pixels in a separate paper clone.
HTTPS images reload anonymously without a referrer and need server CORS support.
Missing, unreadable, or tainted images fail explicitly. Block HTML frames prevent
PNG export; inline HTML keeps its literal-source warning. Limits are 16,384 pixels
per side, 32 Mi pixels in total, and 64 MiB of encoded PNG. Oversized documents
fail before canvas allocation. A 30-second deadline and Close cancel capture.
Canvas dimension checks and an ink scan reject obvious blank or reduced output;
they do not prove complete visual fidelity. Generated PNG preview uses a separate
Blob URL, which closes with the dialog. The native picker must select a new .png
file. Cancellation is checked after capture, after the picker, and before IPC.
After dispatch, Close waits for the actual host result. Native success means a
confirmed host write; browser mode only reports a requested download. PNG export
does not change source, history, selection, baselines, or recovery. Chrome capture
has a visual check. WKWebView, native Save, and Windows/Linux acceptance remain open.
