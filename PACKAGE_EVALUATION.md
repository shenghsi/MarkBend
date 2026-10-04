# Markdown package work evaluation

Date: 2026-10-04. The user approved CodeMirror 6 in a desktop WebView after this
review. TARGET.md now defines the ownership boundary. The new desktop shell is
Tauri. The old native approach below remains comparison evidence.

## Requirements

Typora is the user experience reference. The editor must support formatted
Markdown editing, LaTeX math, Mermaid,
HTML, and code blocks. Original Markdown bytes remain the document authority.
Save must not replace those bytes with Markdown generated from a syntax tree.
Selection, IME, history, save, recovery, and platform behavior still need checks.

LaTeX here means inline and display mathematics within Markdown. Support for
complete TeX documents has not been specified. The HTML requirement does not
yet define a restricted tag set. A limited native HTML subset must not be
reported as complete HTML support.

The evaluation must include one direct formatted editing surface, marks that
appear when needed, source mode, table editing, and editable rendered blocks.
An editor with a separate read-only preview does not meet this target.

## Current evidence

MarkBend has a native macOS text surface, direct formatted edits, source/view
mapping, history, incremental blocks and indexes, save and recovery workflows,
and automated native/runtime checks. The native host already reuses AppKit text
services. We are not building font shaping or IME from nothing.

The parser and projection remain limited. README.md lists missing nested inline
styles, underscore delimiters, multiple-backtick code spans, and full CommonMark
delimiter rules. The full target also includes tables, links, images, footnotes,
math, and other features. Linux has a terminal adapter, not a graphical editor.
Windows has no verified native adapter or complete Bend application toolchain.
Marked-text lifecycle tests do not establish a complete Chinese/Japanese IME
session. Existing checks do not establish the first public release gate.

The latest completed cleanup repair is c4e94ec. Its platform gates pass, but
the first exact-source Save failure remains unreproduced with unknown cause.
The active timing batch is exploratory. It does not establish a speed change.

## Work comparison

| Work | Current Bend engine | Native parser and renderers | Editor framework in a WebView |
|---|---|---|---|
| CommonMark/GFM parsing | Implement missing syntax and edge cases | Reuse Comrak; build an adapter | Reuse parser/editor language packages; configure extensions |
| Source-to-view mapping | Extend our maps for every new syntax | Convert parser positions and account for decoded text | Use source editor positions and decorations; integrate Bend byte positions |
| Text input and selection | Keep AppKit; supply other GUI adapters | Same work as current engine | Reuse editor input/selection machinery; check host and Bend integration |
| LaTeX math | Add parsing and rendering | Comrak math nodes plus RaTeX or another math renderer | Reuse KaTeX or MathJax |
| Mermaid | Add fenced-block handling and renderer | Comrak fence nodes plus native Mermaid renderer | Reuse official Mermaid |
| HTML | Add parsing and define native layout support | Comrak parses HTML; native layout remains limited/custom | Browser engine supplies HTML/CSS layout |
| Code blocks | Extend parser/styles and add highlighting | Reuse Comrak and Syntect | Reuse language/highlighting packages |
| Save and recovery | Keep and finish current workflows | Reuse current Bend workflows | Bridge editor transactions to current Bend workflows |
| Linux/Windows GUI | Supply and verify platform hosts | Same host work remains | Reuse a desktop WebView shell; Bend backend portability still needs work |
| Initial integration cost | No migration | Moderate parser/render adapter work | Large editor/host migration and transaction integration |
| Remaining feature work | Highest custom work | Less syntax work; substantial native UI/layout work | Least custom editor/render work after integration |

These are engineering assessments, not measured effort or delivery estimates.
There is no tested package bridge yet. No path has a verified completion date.

## Native reuse path

MarkView already uses Comrak 0.55, RaTeX, mermaid-rs-renderer, and Syntect.
Its parser options enable tables, task lists, footnotes, front matter, and math.
These packages are suitable starting points for an isolated evaluation.

A Rust library with a small C ABI could return syntax nodes, source positions,
and render input to Bend. Bend could retain commands, history, source bytes,
save, and recovery. This changes TARGET.md's rule that Bend owns parsing:
third-party parser correctness would be outside the Bend proof boundary.

Do not copy MarkView's reader projection as an editor model. Its soft breaks
can become spaces, and its HTML handling supports a selected subset. Those
choices are suitable for a reader but do not supply an exact edit mapping.
Comrak node ranges need checks for Unicode, entities, escapes, tabs, CRLF,
links, math, and fenced blocks. Node ranges alone do not map every displayed
character to a source boundary.

Native Mermaid output can differ from official Mermaid. Native math syntax
coverage also needs checks against the required documents. Parser reuse does
not supply editing, nested-list commands, selection, IME, or full HTML layout.

This is the least disruptive reuse path. It is not a complete solution to
general HTML/CSS rendering or cross-platform editing.

## Full editor and renderer reuse path

CodeMirror is the first editor framework to evaluate for source-preserving
live preview. Its document remains text. Decorations and widgets can hide
Markdown marks or show rendered elements while the source is retained.
Obsidian uses this family of editor services.

A WebView can host the editor, official Mermaid, a math renderer, HTML/CSS,
and code highlighting. This removes the need to write native layout services
for each of these content types. The packages are separate components;
there is no single parser that supplies the complete editing and rendering app.

We still need to integrate source byte positions, editor UTF-16 positions,
IME composition, accepted transactions, undo ownership, file operations, and
recovery. Define one owner for committed edits and history. Do not keep two
independent histories that can disagree. The current synchronous Bend browser
effect path does not support the browser main thread, so this path needs an
asynchronous host/backend bridge.

CodeMirror is an editor foundation, not a complete Typora replacement. Table
editing, mark visibility, math/diagram widgets, source-mode switching, and
their selection behavior still need integration. Desktop packaging and host
lifecycle also remain work. Check package licenses and distribution terms
before selecting the dependency set.

ProseMirror and related rich-text frameworks are another option, but parsing
Markdown into a document and serializing it back does not guarantee retention
of the original Markdown spelling. That conflicts with the current save rule
unless we add a separate exact-source edit mapping.

A portable WebView shell does not prove the Bend backend works on Windows.
The shell and backend need separate platform checks. Reusing frameworks
reduces custom work; it does not establish the product latency target.

## Recommendation

Stop expanding the custom Markdown parser before testing package reuse.
Keep existing source, save, and recovery safeguards.

For the least change to the native design, evaluate Comrak plus MarkView's
rendering packages. Use this route only with an explicit HTML support scope.
Do not silently reduce the HTML requirement to MarkView's current subset.

If the requirement includes general HTML/CSS and broad official Mermaid
behavior, evaluate CodeMirror in a WebView with established rendering packages.
This is likely the faster route to that feature set, but it changes the UI
architecture and reduces the amount of editor behavior implemented in Bend.

An evaluation should demonstrate one complete document with all four content
types, direct editing, exact-byte save, selection, Undo/Redo, and IME behavior.
A rendered preview alone is insufficient. Compare the same document and edit
sequence with the current app. Select the architecture from that evidence.
No migration is implemented by this review.

With Typora as the reference, the full editor/framework path deserves the
first evaluation if browser rendering is acceptable. It covers more of the
required work than a parser-only replacement. This priority is an engineering
assessment; integration effort has not been measured.

## Selected desktop design

The user selected CodeMirror 6 in a desktop WebView, then MathJax for formulas.
The app now uses MathJax 4 with bundled SVG fonts. The micromark math extension
finds formula source ranges. MathJax parses TeX. Bend supplies edit commands;
CodeMirror owns input and history. This decision replaces the earlier KaTeX
recommendation for the app's formula renderer. Mermaid can still use KaTeX as
an internal dependency.

## Sources

- Current project: TARGET.md, README.md, ROADMAP.md, PORTABILITY.md, and source.
- MarkView: Cargo.toml, document/parse.rs, math.rs, and images/diagram.rs.
- [Comrak](https://github.com/kivikakk/comrak)
- [Comrak source positions](https://docs.rs/comrak/latest/comrak/nodes/struct.Sourcepos.html)
- [RaTeX](https://github.com/erweixin/RaTeX)
- [Native Mermaid renderer](https://github.com/1jehuang/mermaid-rs-renderer)
- [Syntect](https://github.com/trishume/syntect)
- [Obsidian editor](https://docs.obsidian.md/Plugins/Editor/Editor)
- [Obsidian decorations](https://docs.obsidian.md/Plugins/Editor/Decorations)
- [CodeMirror guide](https://codemirror.net/docs/guide/)
- [ProseMirror Markdown example](https://prosemirror.net/examples/markdown/)
- [KaTeX functions](https://katex.org/docs/supported.html)
- [Mermaid usage](https://mermaid.js.org/config/usage.html)
- [Typora live preview](https://support.typora.io/Quick-Start/)
