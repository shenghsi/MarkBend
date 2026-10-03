# New-file Save As experiment

The product target stays in TARGET.md. This experiment first creates a new file.
It does not overwrite an existing destination. The architect reviewed this scope.

The app must own an outer workspace: Editing, Saving As, or Uncertain Save As.
The transaction keeps the original document, proposed host target, ticket ID,
and exact snapshot. The proposed target does not replace the document destination
until a matching confirmed completion. Cancellation or an invalid candidate
keeps the complete document before ticket creation. Existing pending saves block
a new transaction. Later edits and history remain current.

Completion must match the outer ID and the session's ticket ID and captured
bytes. A failed check keeps the workspace. Pre-publication failure keeps the
original destination. Uncertain publication keeps the whole transaction and
cannot accept an uncontrolled retry. Regular Save and Close must consult this
outer state before app controls expose Save As.

The POSIX host will resolve the canonical parent and validate the new leaf.
It will check the opaque parent identity again when writing, create a unique
sibling temporary file with mode 0600, write exact bytes, and sync. Exclusive
link publication must reject an existing leaf without replacing it. Keep the
temporary descriptor open and check pathname ownership before publication and
cleanup. Recheck that the canonical parent path still names the held directory.
Pathname checks cannot exclude a race immediately after the check. A failure
after publication must report uncertainty when durability is not confirmed.
JavaScript and Windows remain unavailable until implemented and tested.

Automatic checks must cover cancellation, invalid target data, an existing target
left unchanged, parent replacement, temporary replacement, stale completion,
later edits, and failures before and after publication. Use only private test
fixtures. Host publication is isolated; application controls are not yet connected.

src/AppSaveAs.bend contains the isolated outer-state model. Candidate validation
checks absolute paths, valid scalar text, NUL rejection, nonempty leaf and
identity data, and identity byte ranges. The host still establishes canonical
parent authority. Supported edit operations derive their next session from the
retained session. There is no arbitrary session-replacement entry point. This
keeps the saved baseline and save identity with the transaction. The host must
complete through the checked entry point, not the internal result handler.
Focused checks are in tests/AppSaveAsCheck.bend.

The expanded macOS native one/four-thread, Node, and Bun checks passed. They
cover untitled cancellation and adoption, a mismatched snapshot with the same
ticket ID, stale completion, blocked uncertainty, later edits and their history,
and repeated completion after adoption. Linux checks for the same cases also
passed. Architect review found the prior model findings resolved. This evidence
applies to the pure transaction model only.

src/NewFileTarget.bend and its POSIX host now resolve candidates without creating
files. The host checks the canonical parent through an owned descriptor, rejects
existing leaves (including dangling symlinks), and returns PATH1 target data plus
DIR1 parent device/inode data. It closes the descriptor before returning, so
publication must reacquire the directory and check that identity again.

The engine sanitizer checks passed on macOS and Linux for exact paths, parent
identity, rejected targets, 100 repeated resolutions with descriptor counts,
and injected parent replacement. Actual Bend effect checks passed on both systems
for relative, root-parent, Unicode, alias, existing file/directory/symlink,
empty, trailing-slash, dot, dot-dot, and missing-parent paths. They compare exact
raw identity bytes and check that the guard file and directory contents stay
unchanged. Linux also rejected an invalid-UTF-8 canonical parent through an ASCII
alias. The macOS filesystem rejected creation of that fixture with EILSEQ;
that filesystem case was not run there. The strict decoder has a separate raw
invalid-UTF-8 result check. JavaScript resolution remains unavailable.

`sh tests/new_file_target.sh` runs the complete candidate-resolution gate.
The macOS and Linux batches passed, including parent replacement through the
actual effect, strict raw decoder checks, and JavaScript unavailable results.
The injected Linux build requires GNU feature definitions before system headers.
Architect review accepted this scoped boundary for the publication experiment.
The standard proof gate passed the cancellation and uncertain-transaction laws.
The earlier full EOF batches predate these Save As gates. Publication and app
ownership remain separate tasks.

src/NewFilePublish.bend now has an isolated POSIX publication effect. The expanded
engine checks passed with ASAN and UBSAN on macOS and Linux. They check parent
replacement before and after publication, temporary-name replacement, occupied
file/directory/symlink rejection, wrong identities, repeated descriptor cleanup,
empty files, exact 8 MiB output, oversized rejection, and temporary residue.
The actual Bend effect checks also passed on both systems for exact Unicode,
BOM, CRLF, and NUL bytes, mode 0600, occupied-file preservation, and malformed
identity, parent, and output byte lists. Node and Bun report unavailable without
creating files. Run this batch with `sh tests/new_file_publish.sh`.
Transaction completion and injected effect failures have separate checks below.
App controls still require integration. This is not a full app result.

The driver batch now checks confirmed destination adoption, saved baseline,
undo history, pre-publication failure, and uncertain completion through the
actual Bend effect. It compares every retained target field after uncertainty
and checks undo/redo for old-kept and uncertain sessions. A second driver call
must preserve the result without publication. JavaScript checks unavailable
resolution; they do not yet supply a valid candidate to unavailable publication.
The occupied-after-resolution driver case passed on macOS and Linux. It keeps
the occupied bytes, original untitled destination, baseline, and history, and
clears the matching ticket. Node and Bun also passed with a supplied valid
candidate followed by unavailable publication. The candidate in that test is
synthetic; it does not prove JavaScript target resolution.
A separate ASAN/UBSAN work-object test passed on both systems for 1000 normal
and malformed-buffer completions. It checks balanced allocations and releases
and cleared work data with a synchronous runtime stub. It does not prove
asynchronous runtime scheduling or successful-publication work cleanup.

src/WorkspaceControl.bend supplies isolated Save, Close, and input-ended decisions.
Saving and Uncertain retain the complete workspace and block Save and Close.
Input ending suspends these states even if source bytes equal the baseline.
Editing uses the existing document close and input rules. AppSaveAs also has
edit and selection operations derived from the retained document. These modules
are preparation for app integration, not connected app controls.

src/WorkspaceLoop.bend now keeps the publication outcome with the returned workspace.
Confirmed, old-kept, conflict, uncertain, and unavailable publication have
distinct results. Cancellation returns unchanged state without an error message.
The loop no longer guesses success from the document destination. The macOS
publication batch passed the expanded outcome assertions. The Linux full batch
passed with exit 0 before these latest outcome and workspace-loop checks; it
does not include the new loop. The macOS full batch is still running.

Workspace callback checks now include cancellation and an existing pending
ordinary Save ticket. Cancellation keeps the exact Editing workspace. A supplied
Save As candidate cannot replace or complete the existing ticket. These checks
passed with Node and Bun on macOS and with native Bend, Node, and Bun on Linux.
The event-loop checks remain separate from main app startup and picker integration.

Main startup now enters an Editing workspace and uses the workspace pump.
src/WorkspaceLoop.bend is a compatibility interface to the same implementation in
src/LiveParagraph.bend; it does not keep a second event-loop implementation. The
macOS Node/Bun event checks and Bun startup file checks passed after this move.
Both earlier full batches finished with exit 0, before this startup change.
The Save As picker and host event controls remain unconnected.

The terminal app now accepts `.saveas path`. Actual Linux app checks passed for
untitled and resolved documents, new destination adoption, later ordinary Save,
and unchanged original files. The macOS app now has a Save As button and
Command-Shift-S. Bend checks the workspace before opening its NSSavePanel.
Picker results distinguish selection, cancellation, and unavailable service.
Target rejection retains the host reason. Pending tickets block path resolution.

The real native dialog fixture verified opening and cancellation, but repeatedly
timed out during confirmation. Its private directory/name fields changed while
the selected URL remained stale. These runs failed; they do not prove native
publication or adoption through the dialog. A test-only guard rejects any
selected URL outside the exact private fixture before resolution. Computer Use
inspection also failed because its native pipe could not start. Native dialog
completion remains open; no manual user interaction is required at this stage.

The actual Linux terminal app also passed occupied-target, pre-publication,
publication-time conflict, and uncertain-publication cases. Uncertainty blocks
ordinary Save, another Save As, and Close. Undo/redo still run; EOF reports
retention once and remains suspended until the fixture terminates its child.
Exact target/original bytes and absence of temporary residue are checked.
The timeout is expected only after all uncertainty status assertions; it does
not establish the complete in-memory state, which has separate event checks.
`tests/check.sh` now includes workspace and Linux terminal Save As gates.
