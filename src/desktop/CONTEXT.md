# Desktop file effects

The source record is the exact UTF-8 Markdown document, including its BOM and
line endings. The host's document baseline belongs to the opened or saved file.
A recovery label is display text and is never a trusted file path or baseline.

The host document registry is the first stage of document tabs. Each document
has an independent path, baseline, uncertainty flag, and generation. IDs are
JavaScript-safe integers and are never reused during the process. Old calls
without an ID use document 0. Explicit unknown or retired IDs fail. New tab code
must always send its ID. Registry locks precede document locks; disk work holds
only the document lock. No document operation acquires the registry in reverse.
Async file and image reads capture an ID and generation and check both before
return. Retirement rejects uncertain Save. Quit checks all live documents.
Two documents for one file keep separate baselines, so one Save makes the other
detect a conflict. The renderer and recovery still use one document. Recovery
acknowledgment before retirement and the tab interface remain to be connected.

Recovery copies live in a private app-data recovery folder. A session holds a
cross-platform lease file for its lifetime. Scanning acquires each inactive
session lease and holds it through the bounded read. Active sessions are not
offered. Each renderer start rotates the session token, even without a copy.
Old renderer tokens cannot write or clear a new renderer's copy.

A checkpoint reserves a strictly increasing safe-integer revision. Dirty source
uses a flushed temporary file and atomic replacement. Publication is followed
by directory confirmation and exact field readback. A clear removes only the
current session's snapshot, then confirms the directory, even on a retry when
the file is absent. Failure after publication is uncertain. The revision stays
reserved through failures and clears. Newer retries cannot be replaced by older
requests. Orphan copies remain unchanged when restored or when another document
is saved. This milestone has no removal control for orphan copies.

Reads validate schema, revision, UTF-8, source size, label size, and the opened
regular file. Unix opens are nonblocking and reject symlinks. The source limit
is 8 MiB. A scan covers at most 1000 session folders and reports the limit.
Unix directory sync adds confirmation. Windows does not yet confirm directory
durability. No claim covers every power-loss case or edits before acknowledgment.
Native recovery acceptance remains open.

Application Quit prevents process exit while the main window exists. A host
request token identifies the current confirmation. Repeated requests do not
start more dialogs. Renderer registration rotates pending tokens and invalidates
old approvals and cancellations. The host rechecks Save uncertainty before it
grants one requested zero-code exit. Renderer absence and event errors keep the
process open. Guarded destruction of the last window can exit normally.
Quit retains the acknowledged recovery copy; approved window Close clears the
current copy. Force termination and future multi-window coordination are not
covered. Native Quit acceptance still needs a platform check.

File checks capture the path, saved bytes, uncertainty, and document generation
under the document lock. The worker reads outside that lock. Matching bytes mean
unchanged content; they do not establish file identity. Open, New, Save publication,
and successful save reconciliation advance the generation. Invalid UTF-8 and read
failures leave the baseline unchanged. An external writer can change the file
after a check or validated read. Save keeps its own baseline comparison.

Local image reads capture the document path and generation under the lock. Reads
run outside the lock and recheck the generation before returning raw IPC bytes.
The request's document path must match the host path. Relative image paths use
the document directory; absolute paths can load from untitled documents. Percent
escapes decode once. Invalid encoding, NUL, and URL schemes are rejected. Reads
use the existing bounded regular-file checks and raster signature checks. Image
bytes never change the document baseline. SVG decoding and decoded-size limits
are not supplied by this host command.
