# App save and close experiment

The next experiment connects the actual editor to disk save. The product
requirements remain in TARGET.md. This experiment does not complete the target.
The architect reviewed this scope before implementation.

## Required behavior

Save operates on an existing resolved destination. Requested paths and untitled
documents cannot write. Untitled documents report that Save As is unavailable
and retain the window. Save As remains a separate product task.

Bend creates a pending save ticket before the host operation. The host receives
the resolved path, opaque identity, saved baseline bytes, and exact ticket bytes.
Its structured result distinguishes confirmed completion, old file kept,
replacement uncertain, conflict, and unavailable service. Only a matching
ticket can change the saved baseline. Later edits remain current. An uncertain
ticket prevents another uncontrolled save.

The host checks the destination identity and disk baseline before replacement.
On POSIX, use a held parent directory descriptor and a unique temporary name.
Preserve file mode, write all bytes, sync the temporary file, replace the
destination, then sync the directory. A failure after replacement cannot report
that the old file was kept. A baseline check followed by rename does not prevent
all concurrent external writes; do not claim atomic compare-and-replace.

Close is a request. A clean document can close. A dirty document requires an
explicit Save, Discard, or Cancel choice. Cancel retains the complete session.
Save permits close only after confirmed completion and a clean current state.
Failure, conflict, and uncertain replacement retain the document and window.
Discard requires an explicit runtime choice. Startup recovery does not permit
save or discard.

Use the same events, choices, and outcomes across hosts. macOS uses native
controls. Terminal and JavaScript experiments use explicit commands. A host
without the required service returns unavailable. Windows support requires
implementation and actual Windows checks.

## Automated evidence

Use isolated temporary files and actual app events. Do not save or discard an
existing user document during automated checks.

- Save Unicode, BOM, CRLF, and NUL; reopen and compare exact bytes.
- Save, edit, undo, and redo; check the saved baseline independently of history.
- Change disk bytes externally; require conflict and retain both versions.
- Inject a failure before replacement; retain old bytes and the window.
- Inject uncertainty after replacement; retain the ticket and block close.
- Cancel close; retain source, history, destination, and disk bytes.
- Save on close; close only after confirmed completion.
- Discard; close only after the explicit host choice.
- Reject a missing or unsafe destination without a write.
- Retain untitled documents when Save As is unavailable.

Run focused checks first, then one complete macOS and Linux batch. Check native,
Bun, and Node behavior where the host services are available. Unsupported hosts
must give a structured unavailable result. Keep mathematical laws in LAWS.bend;
runtime filesystem evidence is separate from those laws.

## Current state

The isolated AppSave model is implemented. Focused native, Bun, and Node checks
passed on macOS and Linux. It creates one ticket, retains later edits and
history, preserves destination metadata, and blocks normal close with a pending
ticket. Runtime save and close controls are connected as described below.

The first host connection will be synchronous. Finish the host operation before
accepting another choice, including Discard. An asynchronous implementation must
track active operations separately from uncertain completed operations.

Save-on-close requires both a confirmed outcome and a clean session without a
pending ticket. A failure cannot close the window merely because undo restored
the old baseline. The host loop must enter through AppSave.prepare; requested
is an internal helper and cannot authorize a repeated host operation.

The preceding startup-recovery batches passed on macOS and Linux aarch64. Four
save and close laws and the focused checks are now in the complete batch gate.
The updated macOS and Linux batches passed for the Save integration. The later
EOF change has not yet passed a complete batch.

DocumentSave supplies the native service boundary. It compares exact baseline
bytes, checks PATH1 identity and the canonical path, uses a held parent directory
and an exclusive temporary name, preserves mode, and syncs replacement. Focused
macOS and Linux aarch64 checks passed for exact raw bytes, empty baseline, conflicts, unsafe
targets, temporary cleanup, descriptor counts, and injected failures before and
after replacement, with address and undefined-behavior sanitizers. The actual
Bend effect passed exact byte checks. Checks also passed on both platforms for
detected temporary pathname replacement and malformed identity, baseline, and
output byte lists. The temporary descriptor remains
open until completion; detected replacement is neither renamed nor removed.
Pathname checks cannot exclude a change immediately after the check. Failed
cleanup can leave an owned temporary file. The 8-MiB bound limits writes, not
all allocation before host validation. Mode preservation covers only ordinary
0777 permission bits; ownership, ACLs, special bits, and extended attributes
are not preserved by this prototype.

JavaScript currently returns unavailable and leaves exact file bytes unchanged;
Bun and Node checks passed on macOS and Linux. This is not JavaScript save support. The
Windows branch is unavailable and has not been built on Windows. The native
service is now connected to runtime app events and close controls as described
below. The integrated experiment remains incomplete.

## Runtime connection in progress

The app now accepts Save and a close request. macOS has a Save button and
Command-S. The terminal has `.save`; the JavaScript prompt accepts `.save`,
`.undo`, `.redo`, and `.close`. Dirty close asks for Save, Cancel, or Discard.
Successful focused checks cover the actual macOS window and Linux terminal.
They compare exact saved bytes, exercise Cancel and history, and close only
after the tested choice. Terminal checks also cover Save on close and explicit
Discard. Bun and Node checks cover unavailable save, Cancel, history, and
explicit Discard with unchanged disk bytes.

The native UTF-8 display conversion consumed leading BOM content. The repaired
boundary preserves it. Native host checks compare exact bytes for one and two
leading BOMs, interior BOM, BOM-only text, combining text, CRLF, and NUL. The
window save test checks source bytes before Save and exact disk bytes afterward.

Finite event-pump exhaustion now returns the window and complete document to
the IO driver. It cannot close the document. A separate unsafe outer IO driver
repeats the finite pump; it is outside the pure LAWS imports. Ten thousand
zero-fuel callback cycles passed on native, Bun, and Node on macOS and Linux.
These checks retain source, saved baseline, pending ticket, and destination.
They do not establish product memory limits. Ten thousand actual Cancel choices
across driver cycles also passed on macOS Bun and Node, with exact source and
disk checks at every prompt. This is not a bounded stack or memory measurement.

Integrated failure checks now passed on the macOS window for external conflict,
removed destination, failure before replacement, and uncertainty after
replacement. Compile-time hooks inject the last two cases into separate test
binaries; normal builds have no injected failure. Exact source and disk checks,
Cancel, and undo/redo follow each result. The uncertain case blocks another
Save, asks before close after undo restores baseline bytes, retains the window
after Save on close, and finishes only after explicit Discard. Linux terminal
conflict and removed-destination checks also passed through actual app commands.
These checks do not add atomic compare-and-replace or crash durability.
The architect reviewed these sequences and found no required correction.
Injected failure coverage is macOS native app coverage; the Linux terminal
cases currently cover conflict and removed destinations.

Terminal EOF handling is incomplete: dirty EOF can still repeat close requests.
Add one retained-state suspension and an explicit test wake; do not treat EOF
as Discard or claim complete close protection. The architect recommends a
separate input-ended event and a private test wake descriptor, without a
process-wide signal handler. Wake must resume retained state and must not mean
Save or Discard. A real terminal resume service and dirty process shutdown are
still product work. Bounded driver memory and stack evidence and the updated
full batches also remain to check.

Untitled Save and Save-on-close checks passed on the macOS window, Linux
terminal, and Bun/Node on both systems. They retain the editor, exercise Cancel
and history, and leave a separate sentinel file unchanged. The staged terminal
driver checks complete binary source checkpoints and unchanged path names. It
sends explicit Discard and requires the final successful step; it does not
independently inspect the consumed close-choice constructor. Add that evidence
if later EOF behavior changes. Three repeated Linux runs passed conflict,
missing-destination, and untitled cases. An earlier harness EPIPE cause remains
unproven; asynchronous pipe errors now fail the check with diagnostics.

The complete batch now includes runtime Save checks, untitled checks, injected
native failure checks, and the zero-fuel state-retention check. A new complete
run is required; previous completed batches predate these integrations.

## Input-ended boundary

AppInput supplies an isolated pure model for the next host connection. A clean
document without a pending ticket is close-safe. Dirty and pending documents
are suspended. A resumed wake returns the complete document; an unavailable
service returns retained state without permission to discard. Native one/four
thread checks and Bun/Node checks passed on macOS and Linux aarch64 for exact
metadata, source bytes, saved state, pending ticket, and undo/redo history.
The architect reviewed this scope and found no missing required model rule.

Only a wake issued after suspension may resume the IO driver. The host must
reject stale tokens. This freshness rule is not enforced by the pure model.
Retained state alone does not keep a process alive or survive shutdown. The host
suspension and actual input-ended event remain to connect. Add the model laws
and batch gate after the current full batches finish; their imports remain
unchanged during this run.
# Automatic check update

The full macOS batch passed after Save integration. The full Linux batch found
a checkpoint framing error in the test driver. The driver now requires the
source and suffix after the current header. The split-byte check and five runs
of all three failure modes passed. Architect review accepted this fixture parser.
The full Linux retry stopped with Docker status 125 (connection canceled).
The container list was empty after that stop. This is not a passing full batch.

The isolated InputWait service passed seven wake cases on macOS and Linux:
resume, partial response, repeated wait, old response, extra byte, wrong response,
and control EOF. Each case checks retained source, history, and pending save state.
An injected interrupted read passed on macOS. The engine checks for queued input,
closed notice, and invalid descriptors passed with sanitizers on both systems.
This service is not connected to the app. These checks do not establish a complete
suspension lifecycle or Windows support.

Descriptor-count checks now cover 32 successful, 32 malformed, and 32 EOF waits,
plus 100 queued-input rejections. Counts return to the original value after
owned channels close. Sanitizer engine checks passed on macOS and Linux.
The Linux injected interrupted-read build passed all seven wake cases.
The prototype accepts stream sockets of any address family; its fixtures use
private Unix sockets. A focused synchronous IO-work fixture passed 1000 real
run/call/pack completions on each system with balanced allocation/free counts
and a cleared work pointer. This checks unavailable completion, not runtime
scheduling. The generated macOS sanitizer build failed in corpus_eval; its
cause remains unknown. App suspension remains a separate gate.

`sh tests/input_wait.sh` runs the isolated native engine, work-object, wake,
interrupted-read, and JavaScript unavailable checks. The complete isolated
Linux batch passed. macOS native and separate Node/Bun unavailable checks passed.

The architect approved the next app step: make EOF a distinct input-ended event.
Clean EOF can close. Dirty or pending EOF enters one suspension that retains
the window and complete Bend document. A failed read in the close-choice prompt
must enter the same suspension. The host must not return or restart reads when
no wake service is available. Automatic checks must observe a live isolated
child, one status, no repeated prompts, low idle CPU, stable memory, and unchanged
disk. A watchdog can then terminate that test child. Resume needs a new input
source and remains separate; EOF cannot authorize Discard.

The app now uses that input-ended event and a retained suspension. Linux native
and macOS Node/Bun checks passed for clean EOF, dirty EOF, and close-choice EOF.
Pending-ticket dispatch also passed on Linux native and macOS Node/Bun, including
Undo restoring baseline text. The observation checks found one retained status,
no repeated reads or prompts, bounded idle CPU time, bounded RSS change,
and unchanged disk during 1.5 seconds. These are short observations, not product
memory or latency guarantees. Termination loses this in-memory state.

The CPU observation permits up to 0.05 seconds over 1.5 seconds, with 0.001
seconds for numeric rounding. A macOS Bun check measured a 0.01-second increase;
an exact-zero assertion was too strict for the required low-idle-CPU behavior.
The RSS change limit is 4 MiB. These limits detect busy polling during the short
fixture observation; they do not establish product idle-performance targets.

The synchronous JavaScript suspension requires Atomics.wait. The host checks
that service before accepting edits. Browser main threads are rejected; browser
suspension is not supported. The Windows native branch has not been built or
tested. Resume and durable shutdown remain incomplete.

Terminal EOF now retains an uncommitted draft in the host window state and sends
a separate draft-ended event. That event suspends even if applied text is clean.
It does not apply the draft. The Linux app draft-at-EOF observation passed.
A separate POSIX host sanitizer fixture compared exact draft bytes (BOM, Unicode,
CRLF, combining mark, and NUL), verified applied text stayed unchanged, and closed
the fixture explicitly afterward. The full EOF batch is still pending.

The combined suspension gate passed on macOS for Node/Bun and POSIX draft bytes,
and on Linux for native EOF, pending state, Node/Bun, and draft bytes. The Linux
gate also injected a persistent native poll error; all four native cases passed
with the blocking fallback. The architect accepted the gate scope and idle
budget. Fresh complete batches remain in progress; each result applies only
to its launch snapshot.

Both first full EOF batches parked because the recovery fixture still returned
EOF after displaying recovered dirty text. The app retained that state as
required. The exact owned test children were stopped; both batches ended 143.
The fixture now issues explicit Close and Discard and checks stages and disk
bytes before generated process exit. An external watchdog rejects timeout as
failure. Focused startup checks passed on both systems. The architect accepted
the repair, and fresh full batches are running. The stopped runs are not passes.

The fresh complete EOF batches subsequently passed on macOS and Linux aarch64.
They include the repaired explicit recovery-close fixture, external watchdog,
private wake checks, retained suspension checks, and the earlier Save/recovery
gates. Linux also includes injected persistent-poll failure. These passing runs
do not include the new Save As model or its target-resolution service. Resume,
durable shutdown, browser main-thread support, and Windows remain incomplete.
