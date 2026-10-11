# Project learnings

## [LRN-20261005-GROUPS] best_practice

**Logged**: 2026-10-05
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
Measure growing text edits before accepting a decoration-cache change.

### Details
Standalone group mapping became faster, but total edit results remained mixed.
The first prototype increased 1 MiB overwrite medians from about 43 to 52 ms.
Later group provenance and deferred work reduced that cost. Actual insertions
still gave small median gains and several worse p95 results. A single sequential
pair cannot establish a causal responsiveness improvement. Production source
was restored. The candidate and every timing log remain in the inactive archive.

### Suggested Action
Keep full source and complete decoration checks outside the timing clock.
Retain all samples, failed prototypes, and scope limits. Compare total editing
with the baseline; faster standalone stages alone are insufficient.

### Metadata
- Source: error
- Related Files: tests/performance/preview-growth.test.ts, BENCHMARKS.md
- Pattern-Key: performance.measure_growing_edits

### Resolution
The architect approved rejection. The growing-edit benchmark and complete
edit reference checks remain available. The 16 ms product gate remains open.

## [LRN-20261011-POINTS] best_practice

**Logged**: 2026-10-11
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
Shared positive points can supply context at a changed zero-length boundary.

### Details
A single-layer chunk-skip guard passed 3,240 spaced differential comparisons.
Explicit touching points then exposed nine callback mismatches. A shared old
positive point must remain visible while the other cursor visits a new zero
point at its boundary. Independently removing the common chunk is insufficient.

### Suggested Action
Include exact touching boundaries, zero points, side order, and chunk edges in
range comparison trials. Compare full callback streams and public spans. Do not
infer correctness from separated random ranges or a single-layer certificate.

### Metadata
- Source: error
- Related Files: tests/performance/experiments/point-comparison/check.mjs
- Pattern-Key: ranges.preserve_boundary_point_context

### Resolution
The comparator guard is rejected. Production and installed modules stay intact.
