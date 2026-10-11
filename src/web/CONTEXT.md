# Desktop editor language

The main edit surface has the accessible name Markdown document and uses the
current document title as its description. Labels stay attached through tab
switches, Source mode, and new editor states. Active table-cell edit surfaces
have row and column names and single-line semantics. Their description explains
Enter/Escape exit and Tab navigation, including final-cell row insertion.
These attributes change no source record, selection, history, baseline, or
recovery. Integration checks cover mode/tab changes, cell navigation, Escape,
and exact source/history. Chrome's accessibility tree exposes the document and
single-line cell names, and keyboard Tab/Escape updates focus as expected.
Screen-reader and native platform acceptance remain open; DOM and browser
accessibility attributes alone do not establish that acceptance.

The document bar shows a word count beside the title. It counts the complete
normalized Markdown text, including markup, code, and metadata. Counts exclude
the source BOM; CRLF and bare CR each become one line break. English-locale
Intl word segmentation supplies words; character details count Unicode code
points, including spaces and newlines, not graphemes. A module worker owns the
scan. A 500 ms idle delay precedes snapshot construction. No scan runs inside
an edit transaction. New text clears the old count and cancels in-flight work.
Generation, document identity, and worker ownership reject stale results.
Unchanged text retains its count through presentation and file-status changes.
Page disposal clears timers, listeners, workers, and pending text references.
Worker or segmentation failure shows Count unavailable without a main-thread
fallback scan. This changes no source record, selection, history, baseline, or
recovery. Unit checks cover cancellation and exact source/history. Chrome has
a worker-backed typing check, exact large-paste Undo, and a 400-pixel bar check
with 10,000 words. Native WebView and platform acceptance remain open.

Footnote models retain upstream block-code ranges outside note definitions.
Same-line word edits can map those ranges only with published Markdown CodeText
coverage and complete unchanged word neighbors inside the accepted block.
Every change must qualify; other changes use fresh parsing. Code language
mounts, fence marks, info strings, container prefixes, inline code, and note
definition content cannot supply that coverage. No code value or AST is retained.
Source record, history, baseline, and recovery stay unchanged. Full fresh-model
and exact source Undo/Redo checks cover this foreign path. Isolated state clocks
show a large reduction, but the native frame target remains unverified.

The inactive nesting guard passes resource source/decorations checks and
indentation/completion comparisons, including accepted text and selection.
Its cached scan still visits thousands of new tree objects at 1 MiB. Keep it
outside the app. The earlier resource clocks did not record published-tree
completeness; the fresh decoration builder only agrees with the published tree.
The later code batch records tree lengths, CodeText coverage, and metadata
boundaries. Before guarded code reuse, word edits inside code with a footnote
had roughly one-second medians in both parsers. The isolated check confirms
costly full-body parsing. Guarded reuse is described above. Full preview still
has substantial cost and can publish partial trees in large documents.
Source record, edit surface, history, baseline, and recovery stay unchanged.

An inactive nested-parsing guard retains upstream code and HTML parsing for
every target node and for partial/stopped parses. Only complete, unstopped,
full-input parses without such nodes can omit that pass. Weak cache keys store
structural presence only. Source, decorations, mounted trees, lazy code loading,
language data, and partial-tree recovery have experiment checks. Two comparisons
show lower plain 1 MiB medians, mixed p95, and adverse note cases. The candidate
stays outside the app until resource-bearing performance and guard cost are
measured. No source record, edit surface, history, baseline, or recovery behavior
changes. The native frame target remains open.

A plain-edit CPU profile attributes most samples to language parsing. An
inactive comparison changes only the YAML wrapper, with identical Markdown
configuration. All source and complete-decoration checks pass, but two timing
pairs vary widely and show no consistent direct-parser gain. Production retains
the upstream YAML wrapper. No metadata dispatch parser is added. The next
diagnosis must isolate work shared by both package configurations. This changes
no source record, edit surface, history, baseline, or recovery. Native frame
performance remains unverified.

Plain top-level paragraphs and headings can use a persistent preview block index.
Initial eligibility requires a complete published Markdown Document with exact
0..document-length bounds; parser-context availability alone is insufficient.
Block values retain parser identity and a bounded source envelope, with no
editor state or widget. A single interior word edit with complete neighbors
keeps old and new selections inside its paragraph. The mapped index checks at
most eight adjacent blocks per side. New parser identities are rebuilt until
exact stable outer identities, source envelopes, and line bounds agree, or EOF.
Mapped decorations replace the complete dirty region, including line marks.
Metadata, containers, resources, notes, escapes, structural edits, and uncertain
trees use full construction. Rejected eligibility stops at the first failure.
Full and indexed plans have distinct types. Indexed plans retain no absolute
item array. previewItems explicitly materializes current diagnostic items; it
does not run in a local edit. Selection changes after indexed edits rebuild
through the full path. Context, path, table, configuration, and parser changes
retain guarded fallback. No-op updates can retain an unchanged indexed plan.
This changes no source record, history, baseline, or recovery. Exact source,
selection, Undo/Redo, and complete-decoration checks pass. Two growth comparisons
show large gains on eligible plain documents, with costly first fallback samples
and adverse footnote cases retained. Index creation is full-document work.
These clocks do not establish native frame speed, open time, or memory.

The Files sidebar uses literal native paths and filename text. Folder buttons
load child lists on request. Root refresh, root change, folder collapse, retry,
and page disposal invalidate older request results. Failed reads offer Retry
folder. A chosen root stays unchanged after picker cancellation. Host scans
stop after 2,000 entries and report incomplete lists. Files and Outline share
the left sidebar area. Composition and busy file commands block sidebar actions.
File selection uses the existing guarded Open route or activates an exact-path
tab. Alias and case variants can still create separate tabs. Active file buttons
use aria-current. Directory reads change no source record, history, baseline,
or recovery. Browser fixture checks keyboard expansion, Unicode labels, retained
source/history, and narrow layout with a test folder service. Native picker,
file identity, and platform sidebar acceptance remain open.

The compact document bar follows typora-layout.png. Its title is literal text
with an unsaved mark. Files, Outline, and Source remain available. Tools is a non-modal
disclosure for file and formatting controls. Opening or closing it changes no
source record, edit surface state, history, baseline, or recovery. Pointer
activation retains editor focus and selection. Outer, cell, and form composition
defer disclosure changes. Escape from Tools returns focus to its button.
Link and Image forms, file warnings, and recovery controls stay outside Tools.
A single document hides its tab row and retains Close document in Tools.
Every tab render updates visibility, including failed host retirement.
The writing column is fluid and uses system text fonts. Source mode and cell
input retain monospace fonts. The outline is 250 pixels wide, or 150 in a narrow
window. Chrome checks compact and narrow layouts, dark contrast, Source fonts,
cell padding, and keyboard Escape. Native layout acceptance remains open.

The source record retains original Markdown text, its BOM, and its line endings.
The edit surface is CodeMirror's normalized text document. A source patch maps
edit-surface positions to the source record. CodeMirror owns input and history.
Undo restores both the edit surface and its exact source record.
Source offsets use a weak index owned by an immutable source record. The index
stores each CRLF newline's logical UTF-16 position. Binary lookup counts only
CRLF positions strictly before the requested position; LF and bare CR need no
extra offset. A new record builds its index on first lookup. Undo can reuse the
old record and index. Source patches, Bend Return, table proposals, and image
paste checks use this mapping. Index construction is still a full source scan;
it is measured separately from cached lookup and is not an incremental rope.
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

Paragraphs and headings with inline HTML use a deferred semantic projection.
The upstream GFM/math tree retains heading level, Markdown formatting, formula
values, and image slots. The shared raw parser validates a complete fragment
before resources start. Inert text formatting stays in the edit surface and
uses its theme and natural height. Authored slot attributes, actions, classes,
and IDs cannot enter that surface. Inline styles and unsupported HTML retain
the isolated frame with a visible notice. HTML blocks keep their frame route.
The widget retains its exact parser block source range. Selecting it reveals
source. Container prefixes remain in the source record. The shared document-text
cache retains accepted full-body paragraph and heading AST nodes and image
definitions outside metadata. Projection requires both parser types and exact
UTF-16 block ranges to agree, then creates a new root without changing cached
nodes. It never strips container text or selects the nearest node. Range/type
disagreement, including a partial block, uses the isolated fallback. Multiline
quotes and lists retain package content and original resource source ranges.
Document footnote ranges supply global numbers, including repeated references.
Only the selected node and accepted image definitions enter projection; no
synthetic note definitions or second footer is needed. Missing notes stay literal.
The widget owns its quote border. Covered source lines have no duplicate border;
uncovered quote lines retain theirs. Selecting only the first-line prefix reveals
the paragraph and all its continuation prefixes together. Selection groups
include that prefix. Full decorations remain the differential reference.
Retaining AST nodes adds memory and requires a full body parse, even when the
HTML block has no image syntax. These rendering checks establish neither typing
speed nor idle memory. Reference changes conservatively replace body HTML widgets.
List paragraphs own their same-line markers in one block widget. A separate body
child owns deferred HTML and resource results. Bullet, number, and task controls
retain their parser source ranges and existing input guards. The replacement
covers the first-line prefix, while projection keeps the exact paragraph range.
GFM task content starts after its task marker and horizontal separator; exact
package range agreement still gates projection. Same-line nested markers share
one prefix column and have no overlapping standalone widgets. Markers on later
lines stay separate. Later paragraphs in loose items do not repeat a marker.
Selection includes the complete list owner and the physical first-line prefix.
Marker equality, shifted ranges, groups, and selection updates retain this data.
Chrome checks marker alignment, keyboard source reveal, task toggles, Unicode
input, and exact Undo/Redo. Native list-HTML presentation remains open.
Semantic text widgets use ordinary paragraph spacing. Source blank lines remain
line boxes; they supply spacing between loose items and paragraphs. Tight list
items have no additional widget margin. Heading sizes and weight match source
heading presentation. Normal text whitespace joins soft breaks, while generated
br elements keep hard breaks and inline code retains its spaces. Isolated HTML
keeps its frame spacing. Every semantic replacement includes its physical
first-line prefix, with exact AST/source bounds retained separately. Quotes and
indented headings therefore have no prefix-only line before their widget.
Chrome rectangle checks match plain and HTML paragraph/heading heights and
retain Source mode line heights. Pointer reveal keeps source and history.
The later Unicode/keyboard browser batch was interrupted by a tool timeout;
reconnection failed before state or a screenshot could be read. That batch is
unverified. Automated prefix reveal and exact Undo/Redo checks pass. Native
layout and IME acceptance remain open.
Opening source, edits, path/document changes, removal, and Source mode cancel
deferred validation and nested jobs. Failure after partial resource startup
releases those mounts before publishing fallback. Rendering changes no source,
history, baseline, or recovery. Chrome checks formula and image pixels, heading
and quote layout, Unicode typing, Source mode, and exact Undo/Redo with a test
host. Native body-HTML input and display acceptance remain open.

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
Full fallback edits still enumerate all top-level blocks and assemble the complete decoration set.
An edit-decoration group prototype was rejected after mixed total timing results.
Its inactive source and measurements are under tests/performance/experiments/.
A later shifted ordinary-range cache transfer was rejected after every growing
edit median got worse. That candidate was removed exactly. A separate CPU
profile attributes most preview-update samples to decoration construction and
cached collection; direct oracle calls and unattached GC are excluded. A later
instrumented diagnostic separates traversal, validation, hit shifting, decoration
enumeration, suppression, and combined set sorting/assembly. Timer reads add cost.
When production construction has no replacement widgets, it skips the identity
suppression filter and its array copy. The fresh reference retains that filter.
All replacement-bearing paths stay intact. Two timing pairs show small median
reductions on most affected routes, with mixed p95 and variation in unchanged
footnote routes. This removes redundant work; it proves no tail-latency gain.
Neither profile nor editor-state clocks establish native frames.
The retained test prototype uses a persistent block RangeSet for plain paragraphs
and headings. Local word edits rebuild their paragraph and adjacent new tree
identities until exact stable boundaries or EOF. Two or three blocks are visited
in both tested document sizes. Its explicit settled-tree counts are not latency
results. Production integration is described above; parser-context completion
must not be confused with the tree published in editor state.
The growing-edit benchmark checks exact source and complete decorations after
every insertion. It does not establish native input or screen-frame performance.
Cached collection uses one lazy normalized-text snapshot per call to locate
physical lines and compare envelopes. A position on a newline belongs to the
preceding line. The snapshot and last-line interval stay local to the call;
new cache entries obtain their bounded envelope through document slicing.
Decoration construction and selection groups retain CodeMirror line lookup.
The full collector remains independent of the temporary snapshot.

Decoration construction reuses raw ranges for immutable preview items. A weak
item key stores only ranges and selection, table-editing, and physical-line
conditions. Shifted items get new widgets with current source coordinates.
Global replacement suppression runs when replacements exist. Range sorting still
runs on each construction.
The reference builder bypasses this cache. Small-document reparsing can replace
unchanged items, so reuse is not guaranteed after every source edit. This lowers
some measured construction costs; it does not establish the 16 ms frame target.

Table previews have compact Table tools controls. The structure group starts hidden. Cell
activation opens it, and cell exit closes it. A manual close stays closed through
typing and refresh until the next cell activation. Each table has its own group
ID. Disclosure changes no source, edit surface state, selection, or history.
Pointer activation retains input focus. Escape from the group returns focus to
Table tools; outer and cell composition retain the panel and focus. Read-only
state still permits disclosure and disables edit buttons. Table source remains
available with pointer, Enter, or Space activation through the same guarded
handler. Generic widget reveal does not intercept the action buttons. Active
cell restoration opens the new widget's controls after state replacement or
Undo/Redo. Chrome checks these keyboard routes, manual close with Unicode input,
row insertion, Undo/Redo, and compact reading layout. Native acceptance is open.
A table cell has a single-line raw Markdown edit surface. Its CodeMirror view
has no history. Each accepted cell edit patches the source record through the
outer CodeMirror view. Outer Undo and Redo synchronize the cell edit surface.
History retains the active table, cell ranges, and both selection positions.
Deferred restoration mounts the matching child without a source or history edit.
Stale children cannot patch another cell. A later state or user focus change
cancels pending focus restoration. Selection-only child updates retain unchanged
preview decorations. Chrome checks cover cross-cell Undo/Redo, reverse Unicode
selection, focus, and subsequent typing. Native WebView acceptance remains open.
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

Tab in the last navigable table cell appends one body row and opens its first
cell. Header-only tables and omitted last cells use the same validated row plan.
The new row uses the source record's first line ending and the parsed alignment
continuation prefix. Failed insertion consumes Tab and retains child input,
selection, and focus. Shift-Tab retains its navigation behavior. Structure
commands isolate their history event from prior and later typing. Undo restores
the former cell and selection; Redo restores the new row and first-cell focus.
Integration key-event checks pass. Native keyboard acceptance remains open.

Table inline HTML uses the shared upstream HAST raw parser. Only cells with
HTML load that parser. A complete cell fragment protects generated math and
image slots with private custom nodes, then retains inert semantic tags and
dir, lang, and title. Authored resource URLs, actions, styles, IDs, classes,
and slot attributes are removed. Resources start only after validation.
Unsupported fragments show complete cell slot source from Lezer ranges,
including padding and escaped pipes, without column delimiters or container
prefixes. Opening a cell cancels deferred parsing and nested resources. Late
results cannot replace its edit surface. Other cells can refresh while the
active child retains composition. Rendering adds no source or history edits.
Chrome checks formatting, formulas, image pixels, raw cell input, Source mode,
and exact Undo/Redo. Native table-HTML acceptance remains open.

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
The Table toolbar inserts two columns and two body rows after the last selected
outer block. Selected text stays intact. Inside a list, quote, or fence, the
complete outer block supplies the anchor, including internal blank lines.
Blank space outside blocks uses the physical line start. New separators use
the source record's first line ending. The complete proposal must contain the
exact new top-level table and retain every original outer block's ranges and
parent. The final filtered transaction retains the accepted changes, selection,
and active cell. Live preview opens the first header cell; Source mode selects
its text without an active child. One isolated outer Undo step restores prior
source and selection. Redo restores the new table and header input. Existing
row and column controls resize it. Native insertion acceptance remains open.
Column commands patch all rows in one history transaction. New rows use the
source record's first line ending. Existing slot text stays unchanged except
for the requested slot or alignment token. Empty edge cells and one-column
tables get the outer delimiters needed for valid GFM. New headers use Column.
Nested-table previews omit container prefixes only while rendering. Their
source retains each prefix. Structure commands support parsed lists and quotes,
including combined and tab prefixes. New rows copy the alignment row's
continuation prefix. Complete parser trees before and after the proposal must
retain the table, its container bounds, and surviving row ranges. Unsupported
changes retain the active cell and offer Table source. The exact final
transaction must retain the validated changes and target cell after transaction
filters run. Only then does the command end the child edit surface and dispatch
that transaction. Each command uses one outer Undo step. Chrome checks row,
column, and alignment changes, Unicode cell input, Source mode, and exact
BOM/mixed-line-ending Undo/Redo. Native container-table acceptance remains open.

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
Collection skips only known leaf block types: paragraphs, fenced and indented
code, HTML blocks, tables, and horizontal rules. It continues through document
wrappers, lists, and quotes. The unpruned collector remains the differential
reference for partial and settled syntax trees.
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
line; headings support the first text line of parsed paragraphs and headings
inside lists and quotes. Their exact parser start retains all container prefixes.
Task items and continuation-line selections require source editing. Complete
before/after trees retain the ancestor chain and mapped container bounds.
Setext removal deletes only its parsed underline line. The exact final filtered
transaction must retain the requested patch before dispatch. Rejected commands
retain selection, source, and history. The next line is excluded when a
selection ends at its start. Active cell edits and composition defer formatting.
Commands do not use a partial syntax tree to guess the selected block.
Heading commands can complete a full document parse. These command checks do
not establish typing or first-frame performance. Native heading acceptance
remains open.

Code Block converts complete selected outer blocks to literal fenced code.
With a caret, it uses the current outer block; blank space creates empty content.
Physical boundary insertions retain all original bytes and line endings. The
fence is longer than each content backtick run, with at least three marks.
The final filtered transaction retains requested changes and selection, then
the full parser must accept its exact top-level fence bounds and literal
content. Untouched outer blocks retain mapped ranges and parents. Reverse
selections map inside content; an empty block puts the caret between fences.
Metadata, footnotes, and existing top-level code blocks require source edits.
A selected list or quote, including code within it, becomes literal container
source. One isolated outer Undo step restores source and selection. Native
Code Block input acceptance remains open.

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
checks. The image-size package reads dimensions before a Blob URL or browser
decode. Each side must be at most 16,384 pixels and the image must have at most
32 Mi pixels. Missing or invalid dimension headers fail with editable source.
Clipboard paste and image-file drop use the same check before source edits.
Table preview and print use the shared loader. This header check does not bound
animation frames, decoder allocations, or total document image memory. It does
not validate the complete file; browser decode failures retain source. Local paths
decode percent escapes once and resolve against the host document directory.
Untitled relative paths fail with an edit hint. Local SVG uses strict UTF-8 XML
with an SVG root namespace and no document type. Browser XML parsing and
DOMPurify supply its preview tree. CSS-tree keeps ordinary style rules and
fragment URLs; CSS at-rules, unparsed values, unsafe functions, external hrefs,
embedded images, scripts, event handlers, foreign objects, and animation are
removed. Prefixed SVG element names normalize before sanitization. Only the
serialized result becomes a Blob-backed image; authored SVG never enters the
app DOM. Positive pixel or absolute physical dimensions, or a finite positive
viewBox, set intrinsic size. Root width, height, and minimum/maximum sizes
normalize together. SVG input and prepared bytes have the 8 MiB limit and the
same side/pixel limits. These limits do not bound filter complexity or total
decoder memory. CSS resources and SVG data/clipboard images remain unsupported.
Body, table, and print use the same loader and cancellation rules. Chrome drawing,
canvas pixels, source mode, chosen-file copy, Apply, Undo, and print have a check
with a test host. Native SVG acceptance remains open.
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
it does not edit source. In the desktop app, Copy beside document is optional
and starts unchecked. It requires a saved document with no uncertain Save.
Choose then reads and checks the image bytes and copies them to a sibling
stem.assets folder. It fills an encoded relative path; Apply adds the source edit.
Cancel and Undo retain copied files. Late completed or uncertain copies report
their result, even after form cancellation. Stale reads stop before copy IPC.
SVG copies retain the original file bytes, including content removed from the
preview. Sanitized preview bytes never replace the copied asset or source record.
Each picker request has a token. Cancel,
reopening, field input, changed source, and composition reject late results.
Selected path punctuation encodes once; native separators and drive spelling
remain intact. Windows drive and UNC host checks still need a Windows run.

Image-only clipboard paste inserts one PNG, JPEG, GIF, or WebP. Embed in Markdown
is the default. Copy beside document is a desktop presentation preference and
requires a saved document with no uncertain Save. It sends checked raw bytes
through the existing native copy command and inserts an encoded relative path.
Copy never generates base64 or falls back to Embed. A conservative path
reservation protects the source limit before reading; package insertion and the
actual complete source size are checked again after copy. Preference changes
cancel pending reads without source or history effects. Plain text, HTML, and
URI lists retain ordinary CodeMirror paste.
Encoded source must fit the 8 MiB document limit. Package image insertion checks
protect source contexts. The request captures source, selection, tab identity,
path, and generation; later edits, Undo, switches, or presentation effects cancel
it. Busy, composition, and read-only guards run again before dispatch. Accepted
paste adds one outer history edit and no baseline effect. Copy is a separate
file effect. Cancel and Undo retain copied files. Completed or uncertain copies
report their captured document path through an independent notice, even after
tab or cell changes. Rejected
image-only paste is consumed so empty-text fallback cannot delete a selection.
Table cells accept raster paste through their filtered child edit and outer
history. The accepted package reference context protects code, math, links,
HTML, and existing image syntax. The inserted image must match its exact cell
range. Omitted-cell padding participates in the encoded size check before a
proposed table parse, then the complete filtered outer patch is checked again.
Cell end, switches, source changes, Undo, and selection changes cancel reads.
Cell and outer pastes share result and status request order. Later
requests supersede older result and status publication. Inline data works in an
untitled document and remains in Save and recovery. The image form retains its
separate chosen-file copy option.
Native clipboard acceptance remains open.
Chrome binary clipboard paste, 32 by 32 PNG decode, Undo, and source-mode Redo
have a UI check. The desktop WebView and Windows/Linux paths remain unverified.
The same Chrome checks cover paste into a selected table cell and Enter.
Chrome also checks copied clipboard bytes, relative-path rendering, and exact
Undo/Redo in document text and table cells with a test host. Native copy IPC and
clipboard acceptance require their own platform checks.

Native raster or SVG file drop defaults to Link original and inserts an encoded
absolute image path at the outer edit surface's drop position. Copy beside
document is a separate desktop preference and requires a saved document with
no uncertain Save. It leaves the current selection text intact and
adds one outer history edit. The host reads and checks image bytes before
insertion. The proposed source must fit 8 MiB. Document state, scroll, layout,
display scale, input guards, and shared paste/drop request order must still
match after the read. Native and CSS scale must agree; viewport zoom or offsets
are unsupported. Toolbars, other widgets, code, links, math, and metadata
reject insertion. Link original leaves the file in its original location. Copy
publishes the checked original bytes through the shared native copy command;
SVG bytes remain unchanged. A conservative relative-path reservation protects
the source limit before reading. Source, selection, geometry, scale, preference,
and input guards run before publication and again after its result. A new plan
validates the actual encoded path at the captured insertion offset, with no new
coordinate hit test. Undo and cancellation retain copied assets. Copy outcomes
identify their captured document in a shared notice outside document layout;
the notice cannot move the drop anchor. There is no baseline change or recovery
clearance. Chrome geometry and exact source
Undo/Redo have a scrolled-document check with a test image read. Native OS drops,
mixed-DPI displays, and zoom remain open.

Table-file image drops use the same native read and coordinate guards. A rendered
cell appends the image with a separating space when needed. An active cell uses
its raw edit surface's drop position and keeps selected text. A literal path pipe
encodes as %7C; Markdown escaping retains native backslashes and ampersands.
Accepted package ranges must identify the exact inserted image. Omitted-cell
padding participates in the complete source-size check before a proposed table
parse. Controller, cell range, active child state, selection, child scroll, and
cell layout captures reject late results. Each accepted drop is isolated from
nearby typing in outer history. Inactive-cell activation follows the source edit
and adds no history event. Chrome checks cover scrolled geometry, Unicode text,
exact Undo/Redo, and both cell routes with a test read. Native OS table drops
remain unverified. Copy rebuilds from the captured cell and offset, validates
actual path spelling and complete source size, and uses the same isolated outer
history. Chrome body, rendered-cell, and active-cell copy checks cover exact
bytes, 32 by 32 image decode, and exact source Undo/Redo with a test host.

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
An additional guard accepts ordinary word starts and ,.;:!? strictly inside
an upstream text span. Both complete word or space/tab neighbors stay unchanged.
A retained Unicode letter within the preceding 128 UTF-16 units of the same
span and physical line protects its prefix. All changes retain that letter.
An upstream paragraph or heading can also retain the complete inline-code range
directly before an eligible text span. Ordinary edits at that span's start can
map the model when the code stays on the same physical line and retains all its
source and delimiters. The complete right word/space neighbor must stay intact.
Code opening-boundary edits and protected link/image parents reject reuse.
Mapped text starts include boundary insertions. Code anchors map with their spans.
Other span boundaries, physical line boundaries, Markdown delimiters, and rejected
guards use full parsing. Ampersand text and link/image descendants
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
The app captures these fields before loading the print module. The shared inline
HTML parser, PNG tools, and paper CSS load on request. Duplicate requests are blocked
during loading and preparation; an open modal rejects another projection.
Typing can continue during module loading without changing the captured state.
Composition that starts during loading cancels presentation and retains focus.
Page disposal prevents late presentation, error status, dispatch, and focus.
The build checks the complete static chunk graph and requires the HTML parser and print modules
outside startup but reachable through dynamic imports. Shared Markdown code can
remain in startup. These checks do not prove first-frame speed or idle memory.
The upstream GFM and math packages supply the body tree. The document-language
package supplies the metadata boundary; metadata prints as literal text.
Footnotes keep their preview resource rules. Math and LaTeX fences use MathJax.
Print waits for formula, diagram, code, frame, and image results. A 15-second
timeout or failure retains visible source and permits explicit Print with warnings.
Inline HTML text formatting uses the upstream HAST raw parser on each complete
paragraph, heading, or table-cell fragment. A private custom-node map protects
generated formula and image slots across parser cloning. Exact slot membership,
order, supported ancestry, and one wrapper are required. Authored HTML cannot
create a custom HAST node. Only inert semantic tags and dir, lang, and title
attributes survive before controlled slots expand. Authored classes, IDs,
styles, event handlers, resource URLs, and actions never enter the app DOM.
Unsupported fragments retain their complete enclosing source with a warning
and discard only their pending render jobs. Later jobs keep valid indexes.
Footnote HTML remains literal. The final DOMPurify pass remains in place.
Chrome has a drawing and source/history check for semantic inline formatting,
nested Markdown, MathJax, and table cells. Native Print and PNG acceptance
remain open. Adding the raw parser does not establish open-time performance.
Block HTML uses an isolated
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
PNG export; supported inline HTML uses the ordinary paper DOM. Unsupported
inline HTML retains its source warning. Limits are 16,384 pixels
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
