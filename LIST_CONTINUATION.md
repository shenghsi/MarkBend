# List continuation experiment

The formatted edit surface must support Return as a Bend-owned command. The
host sends the current formatted selection and the command. It must not parse
Markdown or change source before Bend accepts the edit.

## Command contract

- Continue a top-level unordered item with `-`, `*`, or `+` when the selection
  is collapsed at the end of its nonempty content.
- Insert one line ending and the same marker and exact prefix spacing.
- On an empty item, remove the prefix and leave a plain paragraph. This action
  does not insert another list item. Empty means only the marker and its required
  spaces or tabs before the line ending or EOF. The selection must be collapsed
  at the end of that prefix. Preserve the existing line ending.
- At other positions, or with a nonempty selection, use the ordinary newline
  edit. Do not add a list prefix.
- Inside code fences, use the ordinary newline edit.
- During active IME composition, leave Return with the native input method.
- Keep existing source bytes. Use the current line ending where it exists;
  otherwise use the preceding line ending. Use LF if neither exists.
- Each accepted command creates one history event. Undo restores the source
  and selection before Return. Redo restores the accepted result.
- Place the source caret after the inserted prefix for continuation, at the
  start of the plain line for empty-item exit, and after the inserted line ending
  for an ordinary newline.
- Preserve an uncertain Save As transaction and its captured snapshot when
  Return edits the current document.

Nested and ordered lists remain outside this first command experiment. They
remain product requirements. This experiment does not establish full
CommonMark parsing or keyboard IME translation.

## Verification

One batch must check all three markers, exact spaces and tabs after a marker,
empty items, middle-of-item Return, nonempty selections, LF, CRLF, Unicode,
hidden formatting marks, fenced code, and an uncertain Save As workspace.
Check exact source, source selection, formatted view, undo, and redo.

Use native Bend, Node, and Bun for the command checks. Check Linux through the
existing isolated runner. Add one macOS event-loop check for Return outside
composition and its bypass during composition. Run native window checks in
sequence. No user input is required.

src/ListReturn.bend now plans source edits. src/ReturnCommand.bend maps the incoming
formatted selection once, retains the selected snapshot, and applies the source
edit through StoredEditor. Short command cases and the complete 65,536-scalar
line check passed in native Bend, Node, and Bun on macOS. The checks cover exact
source, storage, selection, formatted view, undo, and redo. The standard proof
gate and history-memory gate passed. The macOS native Return event check passed
exact source, displayed text, selection, and undo. The host check passed marked
text bypass and Return dispatch without native source mutation. This does not
prove a complete keyboard IME session.

Return is connected to the macOS formatted editor, terminal `.return`, and
JavaScript `.return`. The latter commands use the current projected selection;
they do not establish native keyboard support. The first implementation scans
source lines and presents the full accepted source. Its product latency is not
established. Run `sh tests/list_return.sh` as a batch. The command batch passed
on macOS and Linux aarch64 before the uncertain-workspace check was added.
The added check passed in native Bend, Node, and Bun on macOS. It uses the
workspace event path and checks Return, Undo, and Redo with the exact retained
target, ticket, snapshot, baseline, and source selection. JavaScript Return
dispatch checks also passed. The updated batch is in the complete application
gate. The full macOS and Linux aarch64 runs passed with the connected Return
command and uncertain-workspace checks. Their fixtures did not yet include the
separate extended command file. That file is now in the permanent list batch;
the updated focused batch passed on macOS and Linux aarch64. The standard proof
gate also passed. The native Save As dialog confirmation gap is
separate and open.

The separate ReturnCommandExtendedCheck.bend adds complete command checks for
exact prefix spaces and tabs, empty-item exit with CRLF, middle-of-item Return,
both code-fence types, and a caret after hidden inline closing marks. Native
Bend, Node, and Bun checks passed on macOS and Linux aarch64. This file
was added separately while the full batches were running, so their existing
fixtures remained unchanged. It is now included in the permanent batch script.

The independent core timing benchmark is `sh tests/return_bench.sh`. It uses
20 Return commands from the same selected baseline for each of 100 KiB and
1 MiB. Cached source, stored-byte, and scene counts plus dirty state are forced
inside the clock interval. Exact source, selection, view, baseline, undo, and
redo checks are outside it. A baseline check precedes the first sample. The
recorded run passed. The core medians were 24 ms for 100 KiB and 440 ms for
1 MiB. Samples and scope are in BENCHMARKS.md. This is not a native frame
measurement.

The connected command now uses IndexedReturn.bend. The planner follows cached
tree widths to the active block and reads that block plus predecessor context.
It does not reconstruct the full source. The legacy planner remains an
independent reference. Every selection pair in the fixtures matches all edit
fields, including reversed selections, mixed endings, empty input, hidden
marks, and closed-fence EOF with LF and CRLF. The connected batch passed in
native Bend, Node, and Bun on macOS and Linux aarch64. The macOS native Return
check and both standard proof gates passed. The generic source-history memory
gate also passed: 243,138,560 bytes on macOS and 242,307,072 bytes on Linux.
That gate checks 20 edits, undo, and redo; it is not a Return-specific memory
measurement. The repeat Return timing run passed. Both medians were 0 ms at
one-millisecond clock resolution, compared with 24 ms and 440 ms before the
change. This does not establish native frame latency. A large active or
preceding block can still require a large scan.

## Native Return measurement

Run `sh tests/native_return_bench.sh` on macOS. The test sends Return through
the real modal event loop and normal stored-session presentation. It starts
the clock immediately before `insertNewline:` and stops after accepted source,
scene, selection, visible layout, and `displayIfNeeded` complete. It does not
measure physical screen presentation.

Each process performs one unmeasured unchanged-selection event to create the
native controls, then 20 Return commands. Undo and its presentation restore the
selected baseline outside each interval. Exact core source, storage, saved
state, view, caret, undo, redo, and host source/scene checks also run outside
the interval. Each Return must clear redo. Initialization must keep histories
empty. A watchdog prevents the test from requiring manual input.

The benchmark fixes a visible legacy vertical scroller and restores the same
clip-view bounds before each sample. It checks caret visibility. This does not
measure the default scrollbar behavior. The cases are 100 KiB and 1 MiB with
many blocks, plus one 65,538-byte unordered item. The complete batch runs each
case with stage clocks disabled and enabled in separate processes. It reports
all samples, median, and nearest-rank p95; 20 samples give only a small-sample
estimate. The initial small-case run passed. Architect review added an
outside-clock result-caret visibility check. The preliminary six-case batch
was stopped before completion. All six corrected batches passed. Modal
timers cannot stop work that
blocks the main thread; the external process timeout bounds those stalls.
The `before_set_ms` stage includes event handling, Bend work, and source
delivery. It does not isolate the core planner.

The uninstrumented median times were 37.722 ms for 100 KiB, 540.832 ms for
1 MiB, and 56.362 ms for the long item. BENCHMARKS.md records all samples,
stage results, viewport settings, and limits. The next experiment will carry
the accepted Return source range to the existing range-update presentation
path. It must preserve single selection mapping, exact bytes, caret, view,
undo, redo, and uncertain-workspace state.

Architect review found a required patch-baseline check for that next change.
The command maps incoming selection before editing. Selection can change mark
visibility, so edit patches can refer to a selected scene that the host has
not yet displayed. The new path must carry the ordered selection and edit
patches from the actual host scene to the final scene. It must not apply edit
patches alone. Add a native case whose incoming selection differs from the
last presented Bend selection, with hidden marks changing visibility. Verify
exact source, attributed scene, caret, undo, and redo before timing the change.

The range path is now connected. ReturnCommand.prepare returns the exact
single computed source edit and result. Accepted editor patches contain the
selection patches followed by the edit patches, with both internal orders
unchanged. Only pending patches change during composition; final snapshot,
histories, index, cache, scene, and host fields remain unchanged. The host
replaces source once before applying these patches. Rejection uses full
presentation of the retained session. Both stored and legacy direct paths
use this contract. Laws cover retained snapshots and rejected sessions.

Prepared-plan and patch-replay checks passed in native Bend, Node, and Bun on
macOS and Linux aarch64. They start from the original host scene and cover all
selection pairs in the short fixtures, including same-chunk changes, empty
items, replacements, Unicode, and fences. Direct-path checks also verify exact
source, view, undo, and redo. Native stored and direct tests passed stale
selection without a preceding Bend selection event. They compare text, caret,
and complete attributes with a full reference render, then check undo and redo.
The corrected focused platform batches, uncertain-workspace checks, generic
history-memory gates, and standard proof gates passed. The full application
gates passed on macOS and Linux aarch64 with the final permanent batch
configuration. Document-memory peaks were 79,282,176 and 78,778,368 bytes;
generic history-memory peaks were 243,040,256 and 242,126,848 bytes. These
memory gates do not establish product idle memory. The repeat six-case timing
batch passed all 120 samples and exact checks. The uninstrumented medians
changed from 37.722 to 2.002 ms for 100 KiB and from 540.832 to 16.872 ms for
1 MiB. The long item regressed from 56.362 to 73.811 ms. Its instrumented
chunk-update median rose from 0.944 to 22.970 ms. The 1 MiB uninstrumented p95
is 20.066 ms; the product target remains unmet. All samples, including stage
outliers, are recorded in BENCHMARKS.md.

The preview now trims matching text and attributes inside each validated
no-pending-native-edit patch range. It keeps UTF-16 surrogate pairs complete
and compares with the current preview after preceding patches. Complete Bend
patches, the rendered scene, chunk identifiers, and chunk order stay unchanged.
Pending native input edits keep their existing path. The host checks passed
Unicode fixture pairs, a long append, and a following style-only update on the
same chunk against complete attributed builds. Native stored and direct
stale-selection checks also passed. The benchmark checks the long item with
an independent full attributed scene after its clock stops. It records every
actual preview range in order, comparison time, and storage-update time.

The first timing run overlapped the Linux application batch. Three
uninstrumented fixtures passed exact checks before the driver was stopped,
but those times are not a valid isolated comparison. Full application gates
passed on macOS and Linux aarch64 after the source move. Their exact handles
returned 0 before the isolated six-case timing batch started. The architect
approved that experiment. The earlier macOS source assertion did not repeat;
its cause remains unknown, and timing work must stop if it returns. The isolated
six-case batch then passed all 120 samples and exact checks. Each instrumented
Return inserted three preview units without removal. The long-item
chunk-update median fell from the earlier 22.970 ms to 1.466 ms. Total timings
remain mixed: the uninstrumented long median was 81.481 ms, while the
instrumented median was 47.596 ms. The additional outside-clock reference
check also differs from the older run. These results establish smaller preview
ranges, but do not establish an overall speed improvement. All samples and
limits are in BENCHMARKS.md. The next experiment will profile before-set work
without changing session ownership or removing correctness checks.
