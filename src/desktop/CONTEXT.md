# Desktop file effects

The source record is the exact UTF-8 Markdown document, including its BOM and
line endings. The host's document baseline belongs to the opened or saved file.
A recovery label is display text and is never a trusted file path or baseline.

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
Application Quit protection and native recovery acceptance remain open.

File checks capture the path, saved bytes, uncertainty, and document generation
under the document lock. The worker reads outside that lock. Matching bytes mean
unchanged content; they do not establish file identity. Open, New, Save publication,
and successful save reconciliation advance the generation. Invalid UTF-8 and read
failures leave the baseline unchanged. An external writer can change the file
after a check or validated read. Save keeps its own baseline comparison.
