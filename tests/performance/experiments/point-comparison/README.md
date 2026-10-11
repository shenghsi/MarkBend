# Inactive point comparison checks

Baseline: 38f8a88. macOS arm64, Apple M4, Node 22.23.2.
Production and installed packages are unchanged. No speed result is claimed.

## Comparator decision

Run `node tests/performance/experiments/point-comparison/check.mjs`.
The script reads installed CodeMirror state 6.7.6, checks its version and source
shape, resolves its one import, and creates two in-memory module copies. It
records the installed source SHA-256. Both use the same range sets and values
as the upstream comparison. No file in node_modules is written.

The naive copy lets findSharedChunks skip positive-point chunks. Three retained
examples change its callback stream: a shared positive point suppresses changed
inner points or marks in another set, but the naive copy reports those changes.
Removing common points can therefore change what the comparison sees.

The guarded copy enables that skip only after the upstream relevant-set filter,
when minPointSize is nonnegative, each side has exactly one relevant set, and
both sets have no nonempty next layer. Chunk identity, mapped position, and
touchesRange checks stay unchanged. Other calls retain upstream behavior.
The exact changes are in changed() and the guard string in check.mjs.

An initial batch of 3,240 spaced comparisons passed. Explicit touching points
and zero-length boundaries then disproved the guard. At source position zero,
the old shared positive point covers 0..10. The new side adds a zero point at
0..0 with equal side values. Upstream reports the old positive point and the
new zero point. The guard reports null and the new zero point. The shared old
point supplies required boundary context even with one layer per side.
guard-boundary-failure.log retains that first failure.

The final batch covers 3,456 comparisons, including chunk boundaries, edits,
zero points, touching points, side values, ranks, multiple sets, and layers.
It finds nine exact callback-stream mismatches among 2,364 eligible calls.
All fallback calls retain upstream behavior. check.log retains every failing
case, callback order, coordinates, values, and boundary notifications. The
script succeeds only when it retains the known rejection controls; its zero
exit status means the rejection check passes, not that the candidate is safe.
Reject this guard. Do not run browser or speed trials for it.

## Static projection evidence

The existing preview inventory now records versioned, read-only layer topology.
preview-eligibility.log shows that the original 1 MiB note preview has three
layers and the resource fixture has two. Neither can use the single-layer guard
without a different projection. These are settled-state fixtures, not input clocks.

static-projection.log separates all points, including zero-length line marks,
widgets, block and multiline replacements, from nonpoint text marks. Both
projections remain static. Each fixture's point projection has one layer before
and after a local edit. The represented static facet inputs include preview,
direction, active-line and search extensions. Dynamic decorations are excluded
as in installed view 6.43.13; static outer decorations are joined. Replacing the
preview input with both projections leaves one relevant single-layer input for
the height comparison in this representative state. This is not a native app
or complete host-extension acceptance claim.

static-spans.log retains a focused regression. At every selection boundary in
three mixed fixtures, point-first and mark-second match the combined full set
in strict comparison callbacks and public span records. The records include
active marks, open counts, and point rank. External decorations before and after
retain their order. The source record stays exact, including BOM and mixed
endings. Nested marks, multiline owners, lists, quotes, Setext headings, notes,
metadata, math, images, tables, Mermaid, HTML, and wide selections are covered.
A reversed-order nested control fails as required. This projection evidence
does not repair the invalid comparator guard.
The focused span check, opt-in inventory, TypeScript check, and Bend proof pass.
proof.log retains the Bend result. Production code is unchanged; no complete
app test or native input acceptance follows from this diagnostic batch.

The next design must skip matching chunks in both cursors together while
retaining shared-point context at changed boundaries. It needs another design
review and exact differential checks before layout or speed trials. Static
production replacements stay intact. Native frame, Open, memory, and platform
targets remain open.
