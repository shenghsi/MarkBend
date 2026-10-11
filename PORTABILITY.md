# Portability Contract

## Active desktop app

The active app uses CodeMirror 6 in a Tauri WebView on macOS, Linux, and Windows.
The source record retains exact UTF-8, BOM, and line endings. Rust owns file
effects, baselines, and recovery. Bend commands compile to JavaScript; Windows
does not need the native Bend compiler. The sections below describe the older
Bend adapter experiments and do not establish active-app platform acceptance.

The portability workflow verifies one frontend artifact before native tests and
builds on all three systems. Its default outputs are debug executables. The
manual build_packages option creates unsigned test packages: macOS app ZIP,
Linux DEB, and Windows NSIS. Archives include a checkout and hash manifest.
No signing or publication runs. Local macOS package construction and ZIP
executable permissions have checks. Windows/Linux package runners, installation,
native IME, and platform runtime acceptance remain open.

## Rule

Native launch paths use the shared guarded Open workflow after recovery startup.
macOS also receives application Open events. Windows and Linux receive paths or
file URLs from launch arguments. No single-instance routing is claimed.
macOS declares Alternate document associations. Linux declares MIME types.
Windows disables the bundled default-association macros and uses owned Open With
registry values instead. Both NSIS hooks compile with makensis 3.13 on macOS;
Windows CI requires their compilation, even for debug builds. This is compiler
evidence, not a Windows registry or native input check. Installation and OS Open
acceptance on all three systems remain open.

The Bend document core must not contain operating-system branches. Platform code
implements the `LiveParagraph` effect boundary and returns the same Bend values.

## Reference Bend adapters

| Target | Input adapter | Status |
|---|---|---|
| macOS native | AppKit direct formatted editor and source field | Implemented |
| Linux native | POSIX multiline terminal checkpoint | Implemented |
| JavaScript | Node/Bun prompt checkpoint | Implemented; browser main thread unsupported |
| Windows native | None | Blocked by the Bend 2 native toolchain |

The Linux terminal adapter is a functional portability baseline. It is not the
final Linux interface. A later GTK or Wayland adapter must keep the same effect
contract.

On 2026-10-03, the POSIX host round-trip and atomic-replacement C experiments
passed in an Ubuntu 24.04 aarch64 container. The atomic check used GCC C11 with
warnings treated as errors. It covered interrupted saves, access modes,
temporary-file collisions, and rejected symbolic-link and directory targets.
This result does not establish the complete Bend Linux batch or native GUI
behavior.

The complete uninterrupted Linux batch subsequently passed with Bend 2.0.34,
Clang 18, and Node 18 in Ubuntu 24.04 aarch64. It covered proofs, recovery and
save states, connected saves, interrupted saves, reconciliation, native byte
reads, document/index/scene checks, memory gates, the POSIX adapter, JavaScript
host checks, and the generated editor's no-input run. Document and history
memory peaks were 87,371,776 and 236,158,976 bytes. These are retained-memory
gates, not product idle-memory measurements. The JavaScript host test uses .mjs
so Node 18 selects its required module mode. Bun was absent; the batch explicitly
reported that generated JavaScript file-byte reads were not run. These checks
do not provide a Linux GUI.

`sh tests/linux.sh` builds a reusable Ubuntu 24.04 test image and runs the full
batch from an isolated repository copy. The Bend 2.0.34 archive is checked against
its release SHA-256 value for arm64 or x64. The first image build and full batch
passed on arm64. The x64 image path has not yet run. This runner does not require
changes to the host Bend installation.
The image now also includes Bun 1.3.11, copied from a digest-pinned Bun image.
The build checks its version. This enables the generated JavaScript file-byte,
save, and recovery checks in the Linux runner. The x64 image path remains
unverified.

The complete Bun-enabled Linux batch passed on Ubuntu 24.04 aarch64 with Bend
2.0.34, Clang 18, and Bun 1.3.11. It included all nine large JavaScript disk
cases: two restart states, five journal interruption stages, and two conflicts.
Small JavaScript restart and journal checks, byte preservation, connected saves,
interrupted saves, and host checks also passed. These Bun-dependent checks are
no longer omitted by the local Linux runner. Document and history memory peaks
were 87,318,528 and 236,220,416 bytes. These are core memory gates, not product
idle-memory measurements. Linux native GUI behavior and the x64 image remain
unverified.

## Shared effect contract

The input-ended experiment retains applied document state, pending saves, and
uncommitted POSIX drafts without treating EOF as Discard. Its native EOF
observation checks run on Linux, which has the terminal adapter. macOS native
uses window events and has no terminal EOF path. Node and Bun use a synchronous
Atomics wait; an unavailable wait host is rejected before editing. Browser main
threads are not supported by this suspension service. Resume remains unavailable,
and process termination loses retained memory. Windows remains unverified.

The complete macOS and Linux aarch64 batches passed after persistent storage,
bounded editor release, and large JavaScript load repairs were added. Both
included Bun checks. Separate Node checks cover large load and core semantics;
Node fork scheduling remains blocked by the Bend effect's `bun:ffi` dependency.
macOS native input during bounded release passed with one/four threads and
one/zero-millisecond pauses. This evidence does not add a Linux GUI or establish
the product performance targets. Details are in BENCHMARKS.md.

The complete macOS and Linux aarch64 batches also passed after the UTF-8,
recovery-plan, and recovery-editor connections were added. The native and Bun
checks cover complete catalog scans, nonfatal errors, duplicate ownership,
real-identity restart recovery, and editor/save snapshot synchronization.
macOS additionally checks the real disk-restart-to-native-window path without
manual input. Core document/history memory peaks were 88,014,848/236,929,024
bytes on macOS and 87,179,264/236,466,176 bytes on Linux. These runs do not add a
Linux GUI or establish product latency and idle-memory targets.

- `LiveParagraph.open` creates one affine host session.
- `LiveParagraph.next` returns Change, Undo, Redo, or Close.
- It can also return Selected or Edit with UTF-16 start and end positions in the
  current formatted surface. Edit also contains replacement text. Bend maps these
  positions to source positions. The foreign events use flat constructor fields.
- `LiveParagraph.set` displays a state calculated by Bend.
- `LiveParagraph.set` also clears the prior preview. `LiveParagraph.append` adds
  one plain, strong, emphasis, or code run. Bend sends all runs before the next
  input checkpoint.
- `LiveParagraph.project` completes the scene and sets its UTF-16 selection.
  macOS supplies an editable formatted surface. The terminal has no native
  pointer selection and uses its existing preview. JavaScript stores the range.
- `LiveParagraph.close` releases the host session exactly once.

The host may own temporary IME composition. Bend owns applied text, undo, redo,
Markdown meaning, and saved document bytes.

Bend Base already supplies windows, image frames, and key, mouse, and scroll
events through C or JavaScript effects. Its current event contract does not
supply native text controls or text-composition events. The custom adapter adds
these services for the editor. The scene position index and its cursor rules
remain in the platform-independent Bend core.

The host receives ordered block chunks with stable identifiers, a freshness
flag, and exact styled runs. macOS and JavaScript can cache those scenes; the
POSIX terminal builds its ANSI preview in full. Each adapter must replace fresh
entries and rebuild cache misses. It must retain only the current blocks.
Legacy scene presentation clears cached blocks. Bend supplies all invalidation
decisions, including history resets. The host does not parse Markdown.

Local edits and selection changes use `LiveParagraph.patch_chunks`. Each patch
has a block start, removed block count, UTF-16 start and length, and replacement
chunks. Apply patches in list order; each range refers to the scene after the
preceding patch. Empty chunks count as blocks even when their UTF-16 width is
zero. Keep untouched chunks and remove discarded identifiers from the cache.
An empty patch list keeps the prior scene. Complete chunk presentation establishes
a new baseline for opening, history, and raw-source replacement. macOS patches
its retained attributed scene; POSIX and JavaScript rebuild their fallback view
from retained ordered chunks.

With a known native text baseline, macOS also applies each patch to its text
field. It adjusts the range for the pending native input replacement. A patch
that contains that replacement consumes it. An unknown baseline, marked text,
or a partial overlap uses complete comparison. Complete presentation clears the
direct patch baseline. Native checks compare final text and attributes with a
complete projection and require no complete comparisons for normal local edits.
Direct patch range diagnostics describe the last applied patch. Fallback range
diagnostics describe the complete comparison interval.

For native input, macOS records the text storage's reported character edit.
That range can include unchanged text. Trim it locally, then expand replacement
boundaries to complete composed characters in both the old and new text.
Multiple storage edits before a commit, or an unknown baseline, keep complete
input comparison as a fallback. Ignore attribute-only storage notifications and
changes made during Bend presentation. Native document checks require zero
complete input comparisons for normal typing.

The macOS source mirror has a balanced position index. Each branch caches scalar
and UTF-16 lengths. Leaves contain at most 512 UTF-16 units, with no surrogate
pair split between leaves. A position lookup follows tree branches and scans one
leaf. A source edit replaces its index range and retains other branches. Complete
source changes rebuild the index. Host checks compare indexed positions with an
independent scalar scan and check exact text, cached lengths, and tree balance.
The POSIX and JavaScript source mirrors retain their current conversion paths.

The macOS chunk builder gathers plain text and exact UTF-16 style ranges, then
creates one attributed buffer per rebuilt chunk. It keeps an immutable copy in
the cache. Up to eight ranges use local storage; larger chunks grow a temporary
range array. Full legacy presentation updates the native field only after scene
assembly. Host checks compare a 12-run chunk with single-run output, including
empty text, Unicode, CRLF, and all defined styles.

The macOS source field also records whether it matches the Bend source mirror.
Independent character edits clear that flag through text-storage notifications;
attribute-only edits leave it set. Bend presentation suppresses those input
notifications and sets the flag after the source update. A known baseline with
matching length permits a range update without complete text comparison. An
unknown baseline restores complete source text on the next source edit. Host
checks cover independent changes with equal and unequal UTF-16 lengths.

The macOS text fields permit noncontiguous TextKit layout. Final projection
scrolls the selected range into view. Native document checks require the edit
caret's glyph bounds to intersect the visible viewport after every edit. The
scroll checks still verify the start, middle, and end after complete layout.
The native batch also runs edits without that complete-layout scroll before the
first edit. This path retains all source, cursor, cache, and visible-caret checks.

Direct edit source positions count Unicode scalars, including separate CR and
LF characters. The host replaces exactly that range with supplied text. macOS
converts it to UTF-16; POSIX converts it to UTF-8 byte offsets; JavaScript uses
code points. Reversed ranges are sorted, and positions clamp at the source end.
Selection changes keep the source mirror. Native checks compare the mirror and
raw editor with Bend after Unicode input, composition, deletion, undo, and redo.

The C boundary follows Bend 2.0.34: native Nat values are exact 48-bit integers;
HostChunk records own three fields; their Bool field is an unboxed 0/1 value.
HostPatch records own five fields; their four Nat fields are inline native values.
Direct Bool effect arguments use constructor terms. Runtime ownership helpers
consume shared list and record fields. Recheck this layout after compiler updates.

## Platform checks

Every change to the host boundary must pass:

1. `bend PROOF.bend`
2. A native build on macOS.
3. A native build on Linux CI.
4. A JavaScript build.

On macOS, `clang -U__APPLE__ -D__linux__ -fsyntax-only tests/linux_host_syntax.c` checks the real POSIX
adapter against a minimal Bend runtime declaration surface. This is an early
check only. It does not replace the Linux CI build.

`.github/workflows/portability.yml` performs complete native Bend builds on
macOS and Ubuntu. A pull request must pass both jobs before merge.

Run `sh tests/check.sh` for the complete local batch. This is also the CI entry
point. Style codes are 0 for plain, 1 for strong, 2 for emphasis, and 3 for code.
Codes 4 through 9 are headings at levels 1 through 6. Code 10 is a quote line;
code 11 is a list item. macOS supplies font sizes and paragraph styles. POSIX
uses ANSI bold for headings and italic for quotes. JavaScript stores these codes.

An adapter must return an explicit error or documented fallback. It must not
silently discard input.
