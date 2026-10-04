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
