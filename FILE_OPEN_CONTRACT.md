# Resolved document opening experiment

App startup now obtains a resolved destination from its file-opening effect.
It keeps the requested path, resolved path, and opaque document identity.

`DocumentFile.read_raw` now supplies a separate native prototype. Its filesystem
work runs on a helper thread. A macOS probe opened a regular file and rejected
a directory and a missing path. The architect reviewed descriptor closure,
buffer ownership, read limits, and the final destination check. Exact native
checks passed on macOS and Linux for Unicode paths, resolved symlink paths,
identity bytes, invalid UTF-8 raw bytes, empty files, the exact 8-MiB limit,
oversized files, directories, FIFOs, missing files, and NUL in a requested path.
Deterministic replacement and resource checks passed on both native platforms.
The worker returned ESTALE after replacement. The checks compare old and new
bytes, count descriptors, and call the real packing cleanup path. Sanitizer
checks passed, including Linux leak detection. Bun and Node also supply this
file result. Their exact byte and resolved-document checks passed on macOS and
Linux. The host rejects systems without the required file-opening flags. A
browser has no file host. Windows remains unverified. JavaScript reads are
synchronous during startup. The current app calls this file effect.

Automatic JavaScript host checks cover short reads, interrupted reads, errors
after a partial read, aggregate overflow, destination replacement, open failure,
and close failure. A close failure does not replace an earlier read error.

The host result must contain the requested path, resolved destination path,
nonempty opaque document identity, and complete bounded raw bytes. Bend must
decode the bytes before it creates an editor. A successful result becomes an
`AppDocument.Resolved` destination. This result does not authorize a save.

`ResolvedOpen` now validates the pure result. It retains the complete raw result
on rejection and preserves requested paths on host errors. Native macOS, Bun,
and Node checks passed for path, identity, UTF-8, and complete saved-byte state.
Two laws check read-failure preservation and rejection of an empty identity.
The standard proof check passed. `ResolvedFile` keeps the foreign read outside
the pure law imports. This pure check validates result data; the native effect
must supply the filesystem guarantees. Tests through that complete connection
now pass on native macOS and Linux. They check BOM, Chinese, emoji, CRLF, NUL,
full saved state, aliases, empty files, and retained raw rejections. Linux also
checks a Unicode alias whose resolved path bytes are invalid UTF-8. App startup
now uses this connection. Automatic Bun and Node checks on macOS and Linux check the
exact initial source through an alias. They also check that invalid UTF-8,
directories, FIFOs, and missing files stop startup before an editor opens.
The native Linux app entry point also passes accepted and rejected file checks.
The native macOS check calls the app entry point. It checks the exact source
in the native source field and agreement between the preview and the host's
rendered string. It closes the window through the normal delegate event.
Rejected cases must report a file error and must not reach the window display
call. A test-only method guard checks that call before it displays the window.
A valid-file negative control checks the guard itself. A separate watchdog
stops a stalled startup. This check does not independently verify
Markdown rendering or an input-method keyboard session.

The resolved callback check reads a real file through an alias. It checks the
exact requested path, resolved path, and PATH1 identity after selection, local
edits, rejected local and full-source input, undo, redo, and source replacement.
It also checks current source bytes, the complete saved state, and unchanged
disk bytes. These are injected callback events, not keyboard actions. A
test-only effect creates an invalid string for rejection checks; its UTF-8
encoding must fail before injection. Close protection and pending save-ticket
retention are separate checks.

The complete macOS and Linux aarch64 batches passed after resolved app startup,
callback retention, and native startup checks were added. Document memory peaks
were 79,626,240 and 79,065,088 bytes. History memory peaks were 242,925,568 and
242,266,112 bytes. These are core memory gates, not product idle-memory targets.

The recovery connection uses `InitialOpen.Initial`. It retains the exact
observed disk bytes beside the resolved document. `InitialFile` constructs it
from one file read. `AppRecovery` uses those bytes and the opaque identity to
prepare recovery. A blocked result retains the initial document and full plan.
Callers must obtain the initial value from `InitialFile`; its data type does not
prevent a caller from manually wrapping a live session. Model checks cover missing, unique, unrelated, pending-save,
conflicting, duplicate, rejected, unavailable, and invalid recovered records.
Catalog comparisons check exact names, identities, save states, and order.

The actual file/catalog restart connection now passes on native macOS and Linux
aarch64, and on Bun on both platforms. The writer obtains its key from the
initial resolved reader, writes an atomic catalog record, and stops with test
exit code 79. Each reader starts in a new process and reads the real file and
catalog. Cases cover an alias, an unrelated equal-byte file, a pending ticket
whose exact snapshot is on disk, an external conflict, a rejected record, and
two distinct records for the same owner. The checks compare full returned
states and plans, source and catalog bytes, and path-name snapshots. They find
no changes after readers. They do not exclude transient changes later restored,
or simulate power loss. Node has pure and initial-reader checks; this restart
uses the Bend process effect, which requires Bun on JavaScript.

App file startup now uses this recovery connection when both explicit settings
are present: `MARKBEND_STARTUP_RECOVERY_HOST` and
`MARKBEND_STARTUP_RECOVERY_ROOT`. Both absent means disabled recovery. Partial,
empty, NUL, and invalid encoding settings are rejected. An explicit process
capability check stops Node before the unsupported process effect runs. The
demo does not read recovery settings when no source file is requested.

Automatic startup checks passed on native macOS, Linux terminal, and Bun on
both platforms. They compare the complete initial or recovered source and
reject editor display for conflicts, rejected and duplicate records, failed
scans, and invalid settings. Linux prints source bytes with their full length;
the exact comparison includes BOM, Unicode, CRLF, NUL, and following text.
File and directory snapshots detect no changes after startup. The native
macOS driver uses the reviewed display guard and independent timeout. Node
checks normal file startup and explicit unavailable-host rejection. These new
checks are included in the latest completed macOS and Linux aarch64 full batches.
Document memory peaks were 79,675,392 and 78,934,016 bytes. History memory peaks
were 243,073,024 and 242,384,896 bytes. These are core gates, not product idle
memory measurements. These batches precede the new app-save model and service.
Normal product
catalog selection, recovery writes, disk save, and protected close remain open.

The host must resolve the requested path under its platform policy, open the
destination, and validate a regular file. It must read from that descriptor
until EOF. Positive short reads do not mean EOF. The aggregate limit is 8 MiB;
the host can read one additional byte to detect an oversized file. It must
close the descriptor on success and on every failure.

Before returning success, compare the opened descriptor's file identity with
the file at the resolved destination. Reject detected replacement or removal.
Keep the document identity policy consistent with the existing PATH1 experiment:
canonical destination bytes identify a save destination, including across atomic
replacement. This opaque document identity differs from the descriptor's file
identity used to detect a changed destination.

One descriptor prevents a later read from switching to another opened file.
It does not prove that another writer did not change that file during reading.
The final destination check does not prevent a subsequent path change. Do not
describe this result as an atomic snapshot. A later save requires a new check.

Keep resolution, opening, reading, size, and encoding failures as Bend outcomes.
Do not create an editor on failure. Do not add recovery loading in this step.

The automatic checks must cover a regular file, Unicode paths, an empty file,
the exact size limit, an oversized file, invalid UTF-8, a directory, a FIFO,
and a destination replaced before the final check. Compare all returned bytes,
both path fields, and the opaque identity. Check descriptor closure on failures.

Start with native macOS and Linux. A Bun or Node filesystem implementation must
use the same descriptor validation and result contract. Windows remains
unverified. After this boundary passes, connect its identity and bytes to the
existing recovery-plan boundary in a separate experiment.
