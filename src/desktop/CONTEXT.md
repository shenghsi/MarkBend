# Desktop file effects

Chosen-image copy is a separate file effect. The host derives stem.assets from
the captured saved document path and never accepts an output folder from the
renderer. The renderer sends the exact raster bytes checked before publication.
The host bounds bytes and checks signatures; this is not complete image decoding.
The captured document ID, path, and generation must still match. The document
lock stays held through publication. Source, baseline, and recovery stay intact.
Random image names publish without replacement. Unix uses held directory file
descriptors, checks folder identity, and checks temporary-file inode ownership
before publication and cleanup. Failure after publication reports a retained
copy. Cancel and source Undo never remove an image. Ownership checks do not
eliminate every check/use race against another process with the same access.
Windows rejects linked/reparse asset folders and uses no-replacement temporary
publication, but path checks do not prevent every folder replacement race.
Windows directory durability and native picker acceptance remain unverified.

The source record is the exact UTF-8 Markdown document, including its BOM and
line endings. The host's document baseline belongs to the opened or saved file.
A recovery label is display text and is never a trusted file path or baseline.
The CI config disables only frontend rebuilding. Each native job verifies a
shared editor artifact before Rust tests and compilation. Debug executables
are build evidence, not release packages or native input acceptance.

The host document registry supplies document tabs. Each document
has an independent path, baseline, uncertainty flag, and generation. IDs are
JavaScript-safe integers and are never reused during the process. Old calls
without an ID use document 0. Explicit unknown or retired IDs fail. New tab code
must always send its ID. Registry locks precede document locks; disk work holds
only the document lock. No document operation acquires the registry in reverse.
Async file and image reads capture an ID and generation and check both before
return. Retirement rejects uncertain Save. Quit checks all live documents.
Two documents for one file keep separate baselines, so one Save makes the other
detect a conflict. The renderer uses explicit IDs and per-tab recovery queues.
Startup locks the registry, all live documents in ID order, then recovery. It
validates every baseline and native path before replacing sessions for the exact
live ID set. Allocation failure retains the old session map. An empty registry
gets a fresh ID; startup does not require document 0. This startup operation
holds the registry during recovery allocation to keep the returned set consistent.

Recovery copies live in a private app-data recovery folder. A session holds a
cross-platform lease file for its lifetime. Scanning acquires each inactive
session lease and holds it through the bounded read. Active sessions are not
offered. Each renderer start rotates the session token, even without a copy.
Old renderer tokens cannot write or clear a new renderer's copy. The recovery
manager has one session per live host document. Creating a session validates its
host ID and retains the existing token on repeated requests. Renderer startup
allocates replacements for every session before changing the complete map. Failed
allocation leaves every old token and copy intact. Released old copies stay on
disk. Recovery requests for retired host IDs fail without creating a session.

Host retirement requires the exact document ID, current session token, and last
confirmed clear revision. Every accepted checkpoint attempt cancels earlier clear
confirmation before disk work. Failure or a later dirty checkpoint prevents
retirement. Registry, document, then recovery is the lock order. Retirement keeps
the document and recovery locks through removal; a competing checkpoint either
finishes first and prevents retirement, or fails on the retired ID. The renderer
must still lock input and flush its latest capture before clearing a tab copy.

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
are not supplied by this host command. The renderer checks local/data raster
header dimensions before browser decoding, paste, or image-drop insertion.

PNG export is a separate file effect. Binary IPC carries bounded PNG bytes and
an encoded destination header. It does not use or change document baselines.
The host checks the signature, IHDR dimensions, decoded pixels, CRCs, and end
through the PNG package. Animated PNG is rejected. The limits are 64 MiB of input,
16,384 pixels per side, 32 Mi pixels, and 128 MiB of decoded output. File work runs
outside the UI thread. The destination must be an absolute .png path and must not
exist. A flushed temporary file publishes without replacement; a competing new
file remains intact. Readback confirms exact bytes. Unix also confirms the parent
directory; Windows directory durability is not claimed. Failure after publication
reports that the exported file exists or may have changed and needs inspection.
Existing Markdown and other files are never replaced by this effect. Native Save
dialog, WKWebView capture, and supported-platform export checks remain open.
