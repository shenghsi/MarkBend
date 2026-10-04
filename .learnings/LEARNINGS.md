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
