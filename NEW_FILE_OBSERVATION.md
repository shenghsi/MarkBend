# New-file observation experiment

This experiment can resolve an uncertain new-file Save As by confirming a
bounded disk observation. It must not retry publication, replace content, or
delete a file. Reads can update access time. Synchronization is a host effect.

src/NewFileReconcile.bend adopts only a confirmed observation with the retained
ticket ID and exact captured snapshot. Other results retain the complete
workspace. Current edits and undo history remain current after adoption.

src/NewFileObserve.bend checks the retained transaction before calling its POSIX
effect. The host checks PATH1 and DIR1 identities, canonical parent, regular
file type, exact size, and captured bytes. It synchronizes the file and parent,
reads again, compares file metadata, and checks the named file and parent again.
Failure retains uncertainty. JavaScript and Windows return a retained result;
Windows execution is not verified.

Engine ASAN/UBSAN checks passed on macOS and Linux for repeated observations,
descriptor counts, file and parent replacement, mismatched and missing files,
empty files, exact 8 MiB output, oversized rejection, short reads, EINTR retry,
and EBADF rejection. Actual Bend effect and driver batches passed on both systems
for exact Unicode/BOM/CRLF/NUL bytes, malformed byte lists and NUL paths,
wrong parent identity, directory/symlink rejection, adoption, retained target
identities, later edits, and undo history. Node and Bun retain observations.

A separate ASAN/UBSAN work test passed on both systems for 1000 successful,
malformed-buffer, NUL-path, and mismatched completions. It checks buffer and work
allocations, released data, and unchanged fixture content. Its runtime stub is
synchronous; it does not prove asynchronous scheduling.

File-sync EIO, directory-sync EIO, and reported close failures also passed on
both systems with stable descriptor counts. The close-failure fixture closes
the owned descriptor before it reports failure. The standard proof gate checks
that RetainUncertain keeps every workspace. The complete observation batches
then passed on both systems. Architect review found no required correction.

Run `sh tests/new_file_observe.sh` from the project root. The complete observation
batch includes the read and work checks. These checks are also included in the
complete application batch. Reconciliation controls are connected through
Recheck Save As and `.recheck`. A confirmed observation cannot exclude later external changes
or every concurrent change-and-restore sequence.

The Linux app success check passed: Save and Close are blocked before Recheck,
matching observation adopts the target, repeated Recheck does not start another
transaction, and ordinary Save writes later edits to the adopted target only.
The terminal app mismatch and missing-file checks also passed. Both retain the
uncertain transaction and block Save and Close. Native button checks remain a
separate gate.

On macOS, run `sh tests/native_workspace_recheck.sh` when no other native window
test is active. It uses the real Save, Close, and Recheck Save As buttons. It
checks confirmed and retained workspace results, retained target identities,
and unchanged disk content. All three native cases passed. The full macOS and
Linux aarch64 application batches also passed with the connected Recheck
controls. The native Save As dialog experiment remains a separate gate.
