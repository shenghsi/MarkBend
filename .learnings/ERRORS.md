# Errors

## [ERR-20261004-DROP-FIXTURE] Async Save completion and jsdom layout

The file-drop fixture treated an unlocked surface as completed Save. Save permits
input while recovery is pending, so a second file command can still be rejected
as busy. Let the mocked recovery continuation finish before the next command.
The added cell-composition case also reached CodeMirror text measurement. Supply
empty Range geometry in jsdom and keep native geometry acceptance separate. A
passing assertion with an unhandled layout exception is not a passing gate.

## [ERR-20261004-STRIKE-FIXTURE] Parser spelling and selection length

The first strike fixture assumed single tildes were Strikethrough. The installed
CodeMirror parser treats them as Subscript. Use two tildes for this command and
use parsed node ranges for removal. Another fixture selected 20 units of a
21-unit nested span. Use the exact string length when selecting the full span.
Both fixture failures are corrected without changing parser behavior.

## [ERR-20261004-WORD-LIST] Footnote cache can create an ordered-list marker

**Logged**: 2026-10-04T11:36:00Z
**Priority**: high
**Status**: resolved
**Area**: frontend

Deleting `a` from `1a1. text` passed the old ASCII word guard. The fresh package
parse starts plain text after the new `11. ` marker, but the cache kept offset
zero. The new regression failed before the fix. Reject two protected ASCII-digit
neighbors, so at least one unchanged non-digit word character remains. This also
covers nested containers without copying their marker grammar. Unicode edits
must preserve complete UTF-16 code points across every change. Compare the full
cached model and rendered definitions with the fresh-parser oracle.

Related files: src/web/footnotes.ts, tests/web/footnote-incremental.test.ts.

The next audit also found entity completion (`&axp;` to `&amp;`) and shortcut-link
invalidation (`[abc]` label edit with its shared definition). Both change package
text spans after an interior word edit. Exclude spans containing ampersands and
plaintext inside link/image descendants. Continue visiting their children for
footnote numbering. Separate regressions cover entity completion/removal and
shortcut, collapsed, full-reference, and inline link-label edits.

The history fixture first treated two `input.type.compose` updates as separate
Undo events. CodeMirror always joins continuation updates; `.compose.start`
starts a new composition. Use the package event contract and check exact source
after Undo/Redo of complete groups. Annotation tests do not prove native IME.

## [ERR-20261004-IMAGEALT] Image alt text and widget measurement

**Status**: resolved
**Area**: frontend

Image tests found that markdown-it's renderInlineAsText omits code_inline and
text_special tokens inside image alt text. Read plain labels from its parsed
tokens, including decoded entities and code content. A test also selected a
CodeMirror measurement image instead of the preview image. Scope DOM checks to
the preview widget. Syntax parsing stays with the existing Markdown packages.

## [ERR-20261004-NAV] Heading node names and state types

**Status**: resolved
**Area**: frontend

The outline test found that Lezer names underlined headings SetextHeading1 and
SetextHeading2. The earlier preview also missed these names. Match both names
and use their level for outline and preview. The main state factory now passes
callbacks that refer to its editor view; explicit EditorState and EditorView
types prevent circular TypeScript inference. Keep outline and preview heading
checks together.

## [ERR-20261004-VCELL] Virtual cell history and row replacement

**Status**: resolved
**Area**: frontend

The virtual-cell checks found two state errors. A complete source-row
replacement could retain its child and append input to the replacement row.
Clear active cell state for that replacement and destroy the child. Redo also
mapped a virtual point over all appended delimiters and lost the filled cell
range. Retain exact active-cell inverse effects, map their offsets, and validate
the restored range against the new syntax tree. Optional field reads keep
Source mode valid. Add an explicit field type to avoid self-reference inference
errors in the inverse-effect provider. Use Lezer delimiter nodes, not a string
suffix, to distinguish escaped terminal pipes. The 52 web checks cover these
corrections.

## [ERR-20261004-TROW] Table row ranges and edge columns

**Status**: resolved
**Area**: frontend

The structure-command batch found that a nested table passed quote prefixes
from later lines to the renderer. The rendered table then had no cell nodes.
Render individual Lezer row ranges without the container prefixes; source
patches still use the original ranges. Commands inside containers stay disabled.
Rows without outer pipes also need explicit delimiters when an empty edge cell
is inserted, or when deletion leaves one column. Retain existing slot text and
add only the delimiters needed for a valid table. Keep exact Undo tests.
Native keyboard Undo also left focus outside both edit surfaces when it removed
an active column. After history changes, focus the remaining cell view or the
outer edit surface. The focused history test covers this case.
The rebuilt Structure Verify app also retains keyboard focus after Undo removes
the active column, and the next keyboard Redo restores that column.

## [ERR-20261004-TBL] Optional preview state during mode changes

**Logged**: 2026-10-04
**Priority**: high
**Status**: resolved
**Area**: frontend

The table edit batch repeated `Field is not present in this state` when Source
mode changed to live preview. The preview field read table-cell state from the
old Source state, which has no such field. Use optional reads on both states.
Keep the mode-change and history test. The architect must review this correction.
The read-only test also used an unbound StateEffect.of method. Call the method
on its effect type so that the appended lock has the correct type.

- Related Files: src/web/preview.ts, tests/web/table.test.ts
- Reproducible: yes

Optional field reads fix the mode-change test. Calling the effect method on its
type fixes the lock test. The full 37-check batch passes. Native Enter exposed
an outer cursor left inside the table; Enter/Escape now move it outside when
such a position is available. Keep the active-selection exit test.

The next native Enter check still revealed source. The child handled Enter and
was destroyed, then the same event reached the generic widget handler with a
detached target. The generic handler must ignore `defaultPrevented` events.
Keep both handled cell Enter and unhandled widget Enter checks. The architect
reviewed this correction. The native repeat must use the corrected build.
The corrected Table Verify build retains the rendered table after both Enter
and Escape. The full 39-check batch passes.

## [ERR-20261004-DIAGRAM] Mermaid label sanitization

**Status**: resolved

The actual WKWebView check rendered flowchart boxes without their labels.
The sanitizer removes foreignObject nodes. The flowchart-specific htmlLabels
setting did not prevent those nodes. Set the top-level htmlLabels option too,
then check the rebuilt app for Draft, Edit, and Save labels.

The rebuilt QA app shows all three labels. The top-level option uses SVG text,
so the sanitizer can still remove foreignObject nodes.

## [ERR-20261004-AX] Preview text selection

**Status**: in_progress

The native AX selectText helper selected the wrong projected range in CodeMirror
live preview. It did not edit the source. Use real keyboard navigation after
widget activation for the native edit check. Full accessibility remains open.

## [ERR-20261004-MATH] MathJax font selection

**Status**: resolved

The SVG test for AMS matrices and double-struck glyphs found an unexpected
dynamic request for the default NewCM font. The direct output constructor uses
`fontData` for the font class. The `font` option is a font name, not an instance.
Supply the bundled MathJaxTexFont class through `fontData`. Keep the complex
formula check so an accidental network font dependency is detected.

## [ERR-20261004-WEB] First desktop build prerequisites

**Status**: resolved

The first Tauri build lacked icons/icon.png. Add a source SVG and use the
official Tauri icon command to make desktop icons before the build.
The New command also passed a temporary MutexGuard through `?` where Rust
required a Document reference. Bind the guard, then pass its mutable reference.
The desktop development watcher and Rust tests reported the same compile error.
Stop the development watcher during host checks to avoid duplicate builds.

The architect found that post-publication read failures could lose the Save
uncertainty flag in the frontend. Use a structured SaveError for all outcomes.
Check Save must retry directory sync as well as exact bytes. New must reset the
host state. Validate regular files and use bounded descriptor reads.

The composition event test found that CodeMirror `composing` stays false until
the first text change. Use `compositionStarted` to defer commands from the start
of composition. Test the actual compositionstart event and New button together.


## [ERR-20261003-LRT] Long-line Return command JavaScript stack limits

**Status**: in_progress

The 65,536-scalar Return command passed load, selection, and planning, then
failed in source editing. A temporary generated-JavaScript stack diagnostic
identified String.cmp in document block comparison. A tail comparison fixed
that stage. Complete reference views then failed in List.append; tail list
assembly fixed it. Removing the tail source replacement reproduced a failure
in String.take, so that replacement is also required. The complete Node command
check now passes source, storage, selection, view, undo, and redo. Bun and native
checks also passed. Architect review accepted the retained fixes. The standard
proof and history-memory gates passed. Full macOS and Linux application batches
also passed. The native Return event and composition bypass checks passed;
these do not establish a complete keyboard IME session.

## [ERR-20261003-TSE] Terminal driver asynchronous pipe error

**Status**: monitored

A Linux staged terminal run raised an unhandled stdin EPIPE. The cause was not
established. Handle asynchronous stdin errors as test failures with mode, step,
and the captured transcript. Wait for child close, including drained output,
before assertions and fixture cleanup. The next focused run passed all three
terminal cases. Repeat the focused run to check the remaining stream concern;
do not infer a production save failure from the harness error alone.
Three further runs passed all cases. The architect reviewed the error handling
and close wait; the original cause remains unproven.

## [ERR-20261003-UTP] Terminal status has a prompt prefix

**Status**: resolved

The untitled terminal status counter required a line-start match. The terminal
prints its prompt before the status, so the counter rejected a valid sequence.
Match the status within the line and check the expected checkpoint count. The
architect also required exact source checks after Cancel, undo, and redo; the
staged terminal driver now covers those bytes and the final explicit Discard.

## [ERR-20261003-ARR] Architect review rate limit

**Status**: resolved

The integrated save-test review failed with HTTP 429 after the retry limit.
Focused tests had completed, but review was not complete. Retry the same scoped
review on the existing architect agent; do not treat a failed agent turn as
approval or as evidence that a test is sound.
The repeated scoped review completed and found no required correction.

## [ERR-20261003-NSB] Native save fixture consumed BOM during decoding

**Status**: resolved

Repeated native save checks showed actual bytes equal to the fixture except
for its leading EF BB BF. Foundation initWithData UTF8 decoding consumed that
BOM before the test entered text. Construct U+FEFF explicitly in the input
fixture and compare UTF-8 NSData at source boundaries. The architect required
boundary diagnostics before changing production encoding; no production
line-ending change was needed. A later exact Apply-source check found the same
BOM loss in the production live_paragraph_string decoding boundary. Preserve
all BOM characters by adding a temporary ASCII prefix before Foundation decode
and removing only that prefix afterward. Native host checks cover one/two
leading BOMs, an interior BOM, BOM-only text, CRLF, combining text, NUL, and
ordinary text. The actual Apply-to-Save test checks exact source bytes first.

## [ERR-20261003-NST] Native save test observed worker before completion

**Status**: resolved

The modal timer advanced immediately after clicking Save and checked disk before
the save worker completed. Wait for the production Saved status presentation
before checking bytes or sending the next input. This distinguishes the retained
modal window from a completed save checkpoint.

## [ERR-20261003-JSE] Generated JavaScript process exit bypasses assertions

**Status**: resolved

The app integration harness produced no final test message. Bend's generated
IO entry point exits the process during require, so assertions and cleanup
after require did not run. Register a process exit listener before loading
the app. Check the completed event count, outcomes, and disk bytes there, and
remove the temporary fixture in that listener. Prompt-time assertions remain
in the actual host event path.

## [ERR-20261003-ASL] Save and close handler cycle

**Status**: resolved

The first app connection made save completion call a general close handler
that could start another save. Bend rejected that definition cycle. Use a
separate completion handler that can close or retain the document and cannot
start another host operation. This also keeps the runtime save operation
synchronous and prevents an automatic repeated save.

## [ERR-20261003-DST] Temporary replacement fixture directory scan

**Status**: resolved

The Linux replacement fixture found no temporary name through fdopendir on a
duplicated directory descriptor; macOS passed. The architect reviewed the
repeated failure. Its cause was not established, and errno after closedir was
not evidence of a readdir failure. Pass the actual temporary name to the
test-only hook instead of discovering it through enumeration. The fixture now
replaces the exact created pathname and still requires that neither rename nor
cleanup uses the replacement. Keep the production ownership checks unchanged.

## [ERR-20261003-DSF] Native save test feature flags

**Status**: resolved

The standalone POSIX save test set POSIX feature flags without the macOS Darwin
flag. Clang then hid O_NOFOLLOW and mkdtemp. Set _DARWIN_C_SOURCE before headers
on macOS, as in the existing atomic-save test. The generated Bend native effect
compiled without this failure.

## [ERR-20261003-ASC] App save model checking

**Status**: resolved

The first AppSave check matched a computed Boolean and reused an affine session.
Bend requires a helper definition for the Boolean match and a reusable `+session`
parameter for the two independent close checks. Apply both rules before adding
the runtime boundary. A shell command's last exit status can hide an earlier
Bend failure; inspect the checker output as well as the process status.

The retry test also used an IO(App.Document) operation as a bare IO(Unit) step.
Bind its returned document and check it. Chain compilation and execution with
`&&` so an old executable cannot run after a failed compile.

## [ERR-20261003-TBR] Node stack limit in a large mapping reference

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
The large Unicode paste reference used Base recursion on complete text and bytes.

### Error
`bend: memory fault (machine stack overflow?)`

### Context
Native and Bun passed, but Node failed after adding a 5,120-scalar insertion.
The reference used String.take, String.append, and List.length on large values.

### Resolution
Use independent tail loops for prefix extraction, text concatenation, and byte
counting in the reference. Node then passed the same large insertion and the
one-MiB map edit. Production mapping updates use bounded spans and tail loops.

### Metadata
- Reproducible: yes
- Related Files: tests/TextByteMapCheck.bend, TextByteMap.bend


## [ERR-20261003-TMN] Base Map name collision

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: backend

### Summary
Base already declares Map, so a new module cannot reuse that type name.

### Error
`a fresh name (duplicate declaration: Map)`

### Resolution
Use Mapping for the text-to-byte mapping type. Check Base names before adding
new top-level types. This is the same imported-name restriction as Result.

### Metadata
- Reproducible: yes
- Related Files: TextByteMap.bend
- See Also: ERR-20261003-RER


## [ERR-20261003-NRI] Native recovery inspection before control creation

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The native text controls do not exist until the next-event loop starts.

### Error
`Native host source differs from Bend source`

### Context
The recovery test inspected the raw NSTextView immediately after presentation.
The host had not created that control yet. The old direct-input checks inspect
source after the event loop starts.

### Resolution
Start the queued native event loop before inspecting native controls. Keep
model and native-source checks after each returned event.

### Metadata
- Reproducible: yes
- Related Files: tests/NativeRecoveryCheck.bend, tests/native_direct.c


## [ERR-20261003-RER] Recovery editor type name conflicts with Base

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: backend

### Summary
The new module cannot declare Result because Base already imports that name.

### Error
`a fresh name (duplicate declaration: Result)`

### Resolution
Use Outcome for the editor opening result and update its callers.

### Metadata
- Reproducible: yes
- Related Files: RecoveryEditor.bend, tests/RecoveryEditorCheck.bend


## [ERR-20261003-U8C] Invalid Char construction differs by runtime

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
The JavaScript runtime rejects invalid Unicode characters before the encoder runs.

### Error
`bend: 55296 is not a Unicode scalar value`

### Context
The shared UTF-8 check constructed a surrogate Char to test encoder rejection.
Native Bend allowed construction. Bun and Node stopped during construction.

### Resolution
Keep invalid-byte decoding and scalar validation in shared checks. Run invalid
Char construction and encoder rejection in a separate native-only check.

### Metadata
- Reproducible: yes
- Related Files: tests/Utf8Check.bend, tests/Utf8NativeCheck.bend


## [ERR-20261003-PCH] Documentation patch context

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary
Two documentation patches failed because their context did not match complete
current lines. The failed patches made no changes.

### Error
`apply_patch verification failed: Failed to find expected lines`

### Resolution
Read the current README section and use exact complete context lines. Keep
unrelated formatting edits out of the patch. The replacement patch succeeded.

### Metadata
- Reproducible: yes
- Related Files: README.md, tests/check.sh

---

## [ERR-20261004-TIM] Control snapshot manifest included absent files

**Priority**: low
**Status**: resolved
**Area**: tests

The timing build stopped before compilation because the control snapshot has
no root LAWS.bend or PROOF.bend. The manifest assumed both files existed.
Use explicit manifest entries for each snapshot and record those entries.
Keep all source and test files in both manifests. Do not copy current laws
into the old control. No timing sample was taken during this failed build.

Evidence: /tmp/markbend-cleanup-timing.XSxiuP/build.mjs.

## [ERR-20261004-LST] Missing duplication markers in paused list draft

**Priority**: low
**Status**: resolved
**Area**: build

The commit proof gate rejects task_spacing because whitespace is used twice,
then rejects ordered_spacing because delimiter is used twice. The draft needs
explicit positive declarations for those shared values. The architect reviewed
the minimal declaration repairs. This corrects compilation only; new list
behavior remains untested and implementation remains paused.

The compiler also rejects mutual recursion through a later unfilled scanner
definition. Inline the helper into the self-recursive scanner, with architect
review. Run proof as a standalone command: a later successful shell command
must not hide a failed proof exit status.

Matching the computed digit predicate directly is also rejected. Use a filled
Boolean helper with a continuation; keep the recursive call on the scanner's
matched rest. The architect reviewed this form. Do not use unsafe recursion.

## [ERR-20261002-001] native event constructor layout

**Logged**: 2026-10-02
**Priority**: high
**Status**: resolved
**Area**: backend

### Summary

A nested range in a foreign event did not match the compiled constructor layout.

### Error

`bend: memory fault (machine stack overflow?)`

### Context

The native window test sent a selection event with a nested Data range. Bend
flattened that range into the event fields. The C adapter packed one nested field,
so the compiled consumer read an invalid second field. Core checks and mock
adapter tests did not detect this boundary error.

### Resolution

The effect contract now uses explicit start, end, and replacement fields. The
adapter packs the exact constructor layout. A compiled native window test checks
the actual selection and edit events through Bend, including undo and redo.

### Metadata

- Reproducible: yes
- Related Files: LiveParagraph.bend, live_paragraph.c, tests/NativeDirectCheck.bend

---

## [ERR-20260926-001] bend-guide

**Logged**: 2026-09-26T17:00:00+08:00
**Priority**: high
**Status**: resolved
**Area**: infra

### Summary

The Bend command is not installed or is not on `PATH`.

### Error

```text
zsh:3: command not found: bend
```

### Context

- Command: `bend guide`
- Workspace: `/Users/shxi/projects/MarkBend`
- The repository instructions require this command before Bend work.

### Suggested Fix

Install the project-selected Bend toolchain, or add its executable to `PATH`.

### Metadata

- Reproducible: yes
- Related Files: `AGENTS.md`

### Resolution

- **Resolved**: 2026-09-26T17:30:00+08:00
- **Notes**: Bend 2.0.29 is available at `$HOME/.bend/bin/bend`. Checks use the explicit path because that directory is not on the current shell `PATH`.

---

## [ERR-20260927-003] zig-linux-c-check

**Logged**: 2026-09-27T09:35:00+08:00
**Priority**: low
**Status**: pending
**Area**: infra

### Summary

The installed Zig 0.16 compiler reports `FileNotFound` for all C input files.

### Error

```text
zig: warning: argument unused during compilation: '-c'
file.c:1:1: error: FileNotFound
```

### Context

- Both generated Bend C and a minimal C program fail.
- The input files exist and are readable.
- A Clang syntax harness is used instead.

### Suggested Fix

Repair or downgrade the local Zig installation before using it for cross-builds.

### Metadata

- Reproducible: yes
- Related Files: `tests/linux_host_syntax.c`, `PORTABILITY.md`

---

## [ERR-20260927-002] docker-linux-check

**Logged**: 2026-09-27T00:30:00+08:00
**Priority**: low
**Status**: pending
**Area**: infra

### Summary

The local Docker command is installed, but its service is not running.

### Error

```text
failed to connect to the docker API at unix:///Users/shxi/.orbstack/run/docker.sock
```

### Context

- Docker was checked for a Linux portability build.
- Zig is available as a Linux cross-check fallback.

### Suggested Fix

Start the local container service when a full Linux runtime test is required.

### Metadata

- Reproducible: yes
- Related Files: `PORTABILITY.md`

---

## [ERR-20260927-001] foreign-one-field-constructor

**Logged**: 2026-09-27T00:10:00+08:00
**Priority**: high
**Status**: resolved
**Area**: backend

### Summary

Applied paragraph text disappeared because the C effect built a one-field Bend
constructor with `term_pak`.

### Error

```text
ParagraphChanged{text} contained an invalid field after the foreign boundary.
```

### Context

- `term_pak` represents a constructor and a location. It does not allocate a
  node for a constructor field.
- Generated Bend code opens `ParagraphChanged` as a one-word heap node.
- The Bend runtime helper for that representation is `io_box`.

### Suggested Fix

Use `io_box(e, CID(ParagraphChanged), text)` for one-field constructors.

### Metadata

- Reproducible: yes
- Related Files: `live_paragraph.c`, `LiveParagraph.bend`

### Resolution

- **Resolved**: 2026-09-27T00:10:00+08:00
- **Notes**: Replaced `term_pak` with `io_box` for `ParagraphChanged`.

---

## [ERR-20260926-003] live-paragraph-input

**Logged**: 2026-09-26T17:50:00+08:00
**Priority**: high
**Status**: resolved
**Area**: frontend

### Summary

The persistent paragraph window opens, but its embedded `NSTextView` does not
accept user typing.

### Error

```text
The live paragraph window is visible, but typing does not change its text.
```

### Context

- The one-shot native `NSTextField` experiment accepted Unicode and IME input.
- The live experiment embedded and manually pumped an `NSTextView`.
- Replacing the view and using a modal run loop did not give the custom window
  keyboard focus.

### Suggested Fix

Use the proven `NSTextField` control for the live single-paragraph experiment.

### Metadata

- Reproducible: yes
- Recurrence-Count: 3
- Related Files: `live_paragraph.c`, `LiveParagraph.bend`

### Resolution

- **Resolved**: 2026-09-27T00:12:00+08:00
- **Notes**: Replaced the custom window with a proven `NSAlert` text checkpoint. The checkpoint accepts input and returns full Unicode text to Bend.

---

## [ERR-20260926-002] native-paragraph-activation

**Logged**: 2026-09-26T17:35:00+08:00
**Priority**: high
**Status**: resolved
**Area**: frontend

### Summary

The macOS paragraph experiment waits in a modal loop but does not show its dialog.

### Error

```text
./native-paragraph remains active, but no window is visible.
```

### Context

- `native_paragraph.c` creates `NSApplication` and calls `NSAlert.runModal`.
- A command-line process does not become a foreground application automatically.
- Process `67744` remained active after the user ran the experiment.

### Suggested Fix

Set an application activation policy, finish application launch, and activate the
application before `runModal`.

### Metadata

- Reproducible: yes
- Related Files: `native_paragraph.c`, `NativeParagraph.bend`

### Resolution

- **Resolved**: 2026-09-26T17:36:00+08:00
- **Notes**: The host now sets a regular activation policy, finishes launch, and activates before `runModal`. The rebuilt dialog returned committed Unicode text to Bend.

---
## [ERR-20261002-002] captured-tree-memory

**Logged**: 2026-10-02
**Priority**: high
**Status**: resolved
**Area**: backend

### Summary

The indexed document benchmark retained tree branches during source-position
lookup. Twenty repeated parse/edit cycles reached about 849 MB peak memory.

### Evidence and correction

- Twenty full parses used about 81 MB. Twenty edits near the start used about
  90 MB. The full benchmark also visits the middle and end of the document.
- In Bend 2.0.34 generated C, the right branch of `BlockIndex.rank` captured
  the left tree to call `count`. The accessor borrowed the tree, but the closure
  did not release its captured reference after that call.
- Read the cached count before creating the branch closures. The right closure
  now captures the count instead of that tree. The complete benchmark used
  about 88 MB after this change.
- `tests/memory.sh` checks 20 one-MiB parse/edit cycles against a 200 MiB peak
  process-memory limit. This detects this failure; it does not prove the product
  idle-memory target.

### Metadata

- Reproducible: yes
- Related Files: `BlockIndex.bend`, `tests/DocumentMemoryBench.bend`, `tests/memory.sh`

---
## [ERR-20261002-NDB] Native diagnostic build

**Logged**: 2026-10-02
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
The diagnostic called a static host function before its declaration. The shell
then ran an old executable because build success was not a run condition.

### Error
`call to undeclared function 'live_paragraph_text_edges'`

### Suggested Fix
Declare the function before the test uses it. Use `&&` between compilation and
execution, or enable `set -e`, to prevent use of old binaries after a failed build.

### Metadata
- Reproducible: yes
- Related Files: tests/native_document.c

### Resolution
- Resolved: 2026-10-02
- Notes: Added the static declaration and made execution depend on build success.
## [ERR-20261002-CCH] Block cache compiler checks

**Logged**: 2026-10-02
**Priority**: low
**Status**: resolved
**Area**: backend

### Summary
The first cache draft used a name from Base, matched parameters in the wrong
order, and called recursive helpers before their definitions.

### Suggested Fix
Use a distinct result type name. Match parameters in their declaration order.
Use lazy branch closures and an explicit decreasing fuel parameter for trie
insertion. Put imports before definitions. Run `bend file.bend` to check a file;
`bend check file.bend` is not a command.

### Resolution
- Resolved: 2026-10-02
- Notes: The proof check, cache tests, full batch, and native measurements passed.
## [ERR-20261002-HSM] Source history memory gate

**Logged**: 2026-10-02
**Priority**: high
**Status**: resolved
**Area**: backend

### Summary
The new one-MiB source-tree history test passed its exact source checks, but
process peak memory reached 540,246,016 bytes during 20 edits, undo, and redo.
This exceeded the 300 MiB regression limit.

### Suggested Fix
Measure edit-only and edit/undo phases separately. Check source reconstruction,
scene-cache release, and history transitions. Do not raise the gate to hide the
retained memory.

### Resolution
The metadata-only history probe used 216,170,496 bytes; retaining a flat reference
source increased it to 238,960,640 bytes. The full test also constructed a new
expected source and repeatedly counted that source. Removing comparison
reconstruction alone did not meet the limit. The final test compares every
character with the fixture's repeated pattern, then checks the exact inserted
suffix. It still materializes the complete actual source after every step.
Peak memory was 250,429,440 bytes for 20 edits and complete undo and redo.
The 300 MiB limit did not change. Snapshot text remains in shared document trees.

### Metadata
- Related Files: tests/SessionMemoryBench.bend, DirectState.bend, BlockSceneCache.bend

---

## [ERR-20261002-BFX] Unused single-run effect registration

**Logged**: 2026-10-02
**Priority**: medium
**Status**: resolved
**Area**: backend

### Summary
The native build failed after scene drawing moved to one batch effect.

### Error
`use of undeclared identifier 'CID____LIVEPARAGRAPH_LIVEPARAGRAPH_APPEND'`

### Context
The compiler did not emit an identifier for the unused single-run effect, but
the shared C file still registered it. A conditional registration fixed the
Bend build but produced a preprocessor warning in the raw host mock.

### Resolution
The public single-run function now calls the batch effect with one Run. The C
adapter keeps a single-run helper for the batch implementation and mock checks,
without registering a second effect. The native benchmark, POSIX host check,
generated JavaScript program, and proof gate passed without that warning.

### Metadata
- Reproducible: yes
- Related Files: LiveParagraph.bend, live_paragraph.c, live_paragraph.js

---

## [ERR-20261003-HPT] Scene patch type and ownership checks

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: backend

### Summary
The reference view constructor needed an explicit Scene type. The patch replay
checker used its prefix tree for both joining and checking its native length,
but did not mark that argument reusable.

### Resolution
Add the Scene type annotation and mark the replay prefix with `+`.
The complete batch passes, including patch replay, native input, POSIX and
JavaScript hosts, and one-MiB cursor checks.
The extra POSIX syntax command first omitted `-U__APPLE__ -D__linux__` and
selected Cocoa headers in C mode. The command and portability instructions now
use those flags; the POSIX syntax check passes.

### Metadata
- Related Files: DirectState.bend, tests/HostPatchCheck.bend
- Reproducible: yes

---

## [ERR-20261003-RNG] Scene range build errors

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: backend

### Summary
The source rank helper used a `count` field name that hid the count function.
The range helper also used two tuple patterns in one match. Bend rejected that
syntax. Pair is a type function, not a constructor.

### Resolution
Rename the field to total. Match each tuple in a separate helper.
`bend PROOF.bend`, session view checks, and scene cache checks pass.

### Metadata
- Related Files: SceneIndex.bend, BlockSceneCache.bend
- Reproducible: yes

---

## [ERR-20261003-SPL] Scene range update definition order

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: backend

### Summary
The new splice function called build before its definition. Bend rejected it.
The rotation helpers also needed reusable arguments for their branch callbacks.

### Resolution
Move splice after build. Mark shared rotation arguments with `+`.
The new test list also required an explicit `List<&2, T.Chunk>` type.
The zero-argument law proof required parentheses after its function name.
`bend PROOF.bend` now passes without an unsafe definition.

### Metadata
- Related Files: SceneIndex.bend
- Reproducible: yes

---

## [ERR-20261002-HCB] Native chunk freshness field

**Logged**: 2026-10-02
**Priority**: high
**Status**: resolved
**Area**: backend

### Summary
The first native chunk-cache edit reused stale blocks and failed the projection
check. The check stayed unchanged.

### Error
`Native document projection or cursor failed`

### Context
The adapter read the HostChunk freshness field as a True/False constructor.
Generated Bend 2.0.34 C stores Bool fields inside Data records as unboxed 0/1
values. Direct Bool effect arguments still use constructor terms. The compiled
HostChunk owns three fields; its list owns two fields.

### Resolution
Read the record freshness field as a 0/1 value and keep constructor checks for
the direct cacheable argument. Repeated native edits then passed. Host checks
cover refreshed identifiers, reuse, missing entries, bounded retention, and
cache clearing before legacy scene presentation. Consume records and shared
run lists through the runtime ownership helpers.

### Metadata
- Reproducible: yes
- Related Files: BlockScene.bend, BlockSceneCache.bend, live_paragraph.c

## [ERR-20261003-INP] native input range expansion

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
Endpoint checks alone did not expand a replacement to complete composed text.

### Error
The host matrix failed for insertion of a zero-width joiner into `abc`.

### Resolution
Expand complete ranges in both the old and new text until their boundaries are
stable. Keep equal amounts of retained prefix and suffix in both replacements.
The matrix now passes for combining marks, emoji, joiners, flags, and CRLF.
The native event check also found that TextKit's reported range can include
unchanged suffix text. Trim within the reported range before boundary expansion
so the caret stays at the actual input end. The native event check now passes.

### Metadata
- Reproducible: yes
- Related Files: live_paragraph.c, tests/host_roundtrip.c

## [ERR-20261003-HDR] local header in a Bend foreign import

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
A local quoted header was not found in the generated native build.

### Error
Clang could not find `source_index_mac.h` in Bend's temporary C build directory.

### Resolution
Keep the native index implementation in the imported C adapter. The generated
Bend build and the native document check then passed.

### Metadata
- Reproducible: yes
- Related Files: live_paragraph.c

## [ERR-20261003-SCN] opening scan declarations

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: backend

### Summary
The opening benchmark and recursive scan needed explicit Bend ownership and
declaration order.

### Resolution
Mark timestamps used twice as copyable. A recursive function must match its
decreasing tree argument first, before the computed parallel flag. Match only
parameters or fields, and use direct self-recursion instead of a forward call
through an undeclared helper. The benchmark now compiles and runs.
Typed equality propositions are not runtime Boolean comparisons. The scan
check compares each field with runtime Boolean functions.

### Metadata
- Reproducible: yes
- Related Files: BlockSceneCache.bend, tests/OpeningBench.bend

## [ERR-20261003-BUL] bulk cache test declarations

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
The bulk-cache code needed a copyable key and an explicit test-list type.

### Resolution
Mark the partition key as copyable because branch selection and division both
use it. Annotate the test update list as `List<&2, Cache.Entry>` so the compiler
does not attempt inference through fully reduced entries. Missing that type
caused a compiler stack error for a large identifier. Nat literals are limited
to 32 bits; calculate the larger test key with `Nat.mul`. The cache comparison
now passes with the large key, duplicate keys, and identifier zero.

### Metadata
- Reproducible: yes
- Related Files: BlockSceneCache.bend, tests/OpeningScanCheck.bend

## [ERR-20261003-ATR] native paragraph-style reference

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
The 12-run legacy-field check used a reference with no native layout manager.

### Resolution
The test puts several paragraph styles in one paragraph. TextKit applies one
paragraph style across that paragraph, so a bare attributed reference differs
from the displayed field. Pass the single-run reference through the same native
field, fix its attributes, and compare the complete text and attributes with
the new chunk output. Keep the separate exact pre-display buffer comparison.
Both checks now pass, including Unicode, empty runs, and dynamic range storage.

### Metadata
- Reproducible: yes
- Related Files: tests/host_roundtrip.c, live_paragraph.c

## [ERR-20261003-NAV] navigation test session ownership

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The navigation verifier read the session before passing it to the next step.

### Resolution
Mark the session parameter as copyable. The native navigation and resize batch
then compiled and passed, with exact source and independent selection values.

### Metadata
- Reproducible: yes
- Related Files: tests/NativeNavigationCheck.bend

## [ERR-20261003-AFF] Native wrapped navigation

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
The scene update changed native selection affinity at a wrapped boundary.

### Error
Down reached source position 69. After the Bend event, Up reached position 8
instead of 9. Native affinity changed from downstream to upstream.

### Resolution
Capture affinity with the selection event. Restore it when the scene maps back
to the same native range. Clear the pending selection event on a text edit.
The integrated native navigation check passes. Skipping redundant range
assignment alone did not correct the failure.

### Metadata
- Reproducible: yes
- Related Files: live_paragraph.c, tests/NativeNavigationCheck.bend

## [ERR-20261003-FIL] Bend file modes

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
Bend File.open rejects C stdio modes `rb` and `wb`.

### Resolution
The installed native and JavaScript implementations accept `r`, `w`, and `a`.
Use `r` and `w` with File.read_bytes and File.write_bytes. Both byte-preservation
checks passed with BOM, CRLF, NUL, emoji bytes, and invalid UTF-8.

### Metadata
- Reproducible: yes
- Related Files: tests/FileBytesCheck.bend

## [ERR-20261003-NOD] Generated file-byte reads in Node

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
The Bend 2.0.34 generated File.read_bytes code requires bun:ffi.

### Error
Node reports: Cannot find module 'bun:ffi'.

### Resolution
Run the generated byte-read check in Bun. Keep Node checks for the pure
save-state model and existing adapters. When Bun is absent, report the missing
file runtime check explicitly; do not claim Node file-byte coverage.

### Metadata
- Reproducible: yes
- Related Files: tests/check.sh, tests/FileBytesCheck.bend

## [ERR-20261003-RCP] Reconciliation proof cases

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
Reflexivity alone did not prove reconciliation with an unconfirmed sync result.

### Resolution
The current match requires the state and pending ticket constructors to be
known. Import SaveState directly into PROOF.bend and cover both no-ticket and
pending-ticket cases. The generic law then passes for every state and byte list.

### Metadata
- Reproducible: yes
- Related Files: SaveState.bend, LAWS.bend, PROOF.bend

## [ERR-20261003-APT] Ubuntu package index changed

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: infra

### Summary
Linux Bend setup failed before any project checks ran.

### Error
Ubuntu noble-updates universe Packages.gz had an unexpected size:
2200766 bytes instead of 2200764. Apt reported a mirror sync in progress.

### Action
Retry in an isolated container with Acquire::By-Hash=force. Keep the failed
setup separate from the earlier successful Linux C experiment results.
The retry installed the compiler and Bend 2.0.34, and the Linux project checks
started successfully.

### Metadata
- Reproducible: unknown
- Related Files: tests/check.sh

## [ERR-20261003-ESM] Node 18 host test module mode

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
Ubuntu Node 18 treated the ES module host check as CommonJS.

### Error
SyntaxError: Cannot use import statement outside a module.

### Resolution
Rename the host check to host_roundtrip.mjs and update the batch commands.
The explicit module extension preserves import.meta.url and works in Node and
Bun without a repository package setting. Both local runtime checks passed.

### Metadata
- Reproducible: yes
- Related Files: tests/host_roundtrip.mjs, tests/check.sh

## [ERR-20261003-KRN] Independent Bend proof kernel unavailable

**Logged**: 2026-10-03
**Priority**: low
**Status**: pending
**Area**: infra

### Summary
The optional independent proof-kernel check could not build.

### Error
The lean executable was not found. Bend 2.0.34 requires Lean v4.34.0 or a built
kernel supplied with BENDTT for --verdict.

### Context
The required bend PROOF.bend gate passed. Do not describe that result as an
independent kernel verdict. Install the optional toolchain before retrying it.

### Metadata
- Reproducible: yes
- Related Files: PROOF.bend

## [ERR-20261003-MIO] Pure parser used as an IO effect

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The journal driver tried to bind U32.read directly in an IO block.

### Resolution
U32.read returns Maybe, not IO. Use a helper that returns IO.pure on Some and
IO.die on None. The journal interruption test then compiled and passed.

### Metadata
- Reproducible: yes
- Related Files: tests/JournalInterruptedCheck.bend

## [ERR-20261003-HEX] Recovery codec compile errors

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: code

### Summary
The first hexadecimal codec used computed match inputs, bare arithmetic,
Chr as a type, and Nat.to_u32. Bend rejected these definitions.

### Resolution
Use helper functions for computed match inputs. Annotate arithmetic with U32.
Char is the type; Chr is its constructor. Use U32.from_nat and mark shared
bindings with +. The native recovery record checks then passed.

### Metadata
- Reproducible: yes
- Related Files: RecoveryRecord.bend, tests/RecoveryRecordCheck.bend

## [ERR-20261003-CFM] Shared recovery mode consumed twice

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The conflict driver used the affine mode string in two String.eq calls.
Bend rejected both native builds before the experiment ran.

### Resolution
Move mode selection into a helper with a +mode parameter. Pass the IO result
to that helper once.

### Metadata
- Reproducible: yes
- Related Files: tests/RecoveryConflictRestartCheck.bend

## [ERR-20261003-JRS] Large JavaScript recovery stack overflow

**Logged**: 2026-10-03
**Priority**: high
**Status**: resolved
**Area**: code

### Summary
The one-MiB codec failed on Bun 1.3.11 and Node 22.22.3. A temporary stack
trace in generated JavaScript identified recursive valid_bytes as the first
failure. Byte encoding, hexadecimal decoding, record splitting, and byte
comparison also used non-tail recursion.

### Resolution
Use accumulators and tail calls for the version 2 path. Keep match inputs in
parameter order, and put the decreasing recursive input before the accumulator
and validation flag. An attempted mutually recursive decoder also failed the
Bend check; the final decoder has one decreasing self-call. Unmodified generated
JavaScript then passed the full one-MiB round trip on both runtimes. Add this
large check to the JavaScript batch. Native one-MiB behavior and the proof gate
also passed. High JavaScript memory cost remains a separate issue.

### Metadata
- Reproducible: yes
- Related Files: RecoveryRecord.bend, SaveState.bend, tests/check.sh

## [ERR-20261003-ENT] Recovery entry needs a type annotation

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
Bend could not infer the type of a standalone recovery entry constructor.

### Resolution
Annotate the bound value with Entry.Entry. The document identity check then
compiled and passed.
The later truncation check also needed +p because it uses the predecessor in
both String.take and the recursive call.

### Metadata
- Reproducible: yes
- Related Files: tests/RecoveryEntryCheck.bend

## [ERR-20261003-IDB] Shared binding inside IO block

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
Bend rejected a shared local binding inside the identity reader's IO block.

### Resolution
Pass the IO results to a helper with shared parameters. The path identity
restart driver then compiled.

### Metadata
- Reproducible: yes
- Related Files: tests/RecoveryEntryRestartCheck.bend

## [ERR-20261003-RDN] Filesystem rejects non-UTF-8 names

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The recovery directory fixture tried to create a filename containing byte 255.
This macOS filesystem rejected it with Illegal byte sequence. Linux accepted it.

### Resolution
Check creation under the C locale. Accept only the observed Darwin error as
an unavailable filesystem capability and report it explicitly. Continue to
check raw NUL and invalid UTF-8 record bytes on both platforms. Linux still
checks lossless hexadecimal encoding and reading of the non-UTF-8 name.

### Metadata
- Reproducible: yes
- Related Files: tests/recovery_directory.sh

## [ERR-20261003-STB] Comparison timing included final session disposal

### Summary
The restored-snapshot typing benchmark consumed its last session reference
inside the dirty check. The measured 480–689 ms interval included disposal of
redo snapshots. It did not isolate exact byte comparison.

### Resolution
Retain the session across the timers and check it afterward. Measure cached
identity checks and retained exact comparison separately. The corrected macOS
measurements were below one millisecond and 18 ms respectively. Keep disposal
cost separate in later lifecycle measurements.

### Metadata
- Reproducible: yes
- Related Files: tests/StoredTypingBench.bend

## [ERR-20261003-NSB] Native benchmark reference used the wrong insertion position

### Summary
The persistent native benchmark expected prefix insertion. The existing native
document driver inserts X at the end. Native range checks passed, but the Bend
flat-source reference failed on the first edit.

### Resolution
Read the driver operation and build the expected source as original text plus
the repeated suffix. The corrected 20-event native check passed.

### Metadata
- Reproducible: yes
- Related Files: tests/NativeStoredBench.bend, tests/native_document.c

## [ERR-20261003-SRL] JavaScript long paragraph opening reached a stack limit

### Summary
The scene release check opened a 65,536-scalar paragraph through DirectState.
Native Bend passed, but generated JavaScript reported a machine stack fault.
Phase output confirms that opening starts but does not complete.

### Resolution
Keep the actual paragraph opening/release check on native Bend. Test large text,
run, and point-list disposal directly on all runtimes to isolate the release
operation. Those checks passed on native Bend, Bun, and Node on macOS and Linux.
The JavaScript opening defect remains unresolved and is recorded in benchmarks.

### Metadata
- Reproducible: yes
- Related Files: tests/SceneReleaseCheck.bend, tests/SceneReleaseLongCheck.bend

## [ERR-20261003-NRZ] Repeated native window timeout

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
A zero-pause cleanup test timed out when it followed another native window test
in the same process. The same zero-pause case passed in a fresh process.

### Error
Native direct event timed out

### Context
NativeReleaseCheck ran pause 1 then pause 0. The first window passed. The second
window failed. A separate NativeReleaseZeroCheck passed with one Bend thread.
This does not prove that zero-pause cleanup caused the failure.

### Suggested Fix
The driver created a new timeout for each event without canceling the previous
timer when only source inspection was used. Those old timers remained in the
modal run loop. Cancel the owned timeout before enqueue and at source inspection.
The same two-window case failed before this change and passed afterward with
one and four threads. NativeRepeatedWindowCheck keeps this regression in the batch.

### Metadata
- Reproducible: yes, before the fix
- Related Files: tests/NativeReleaseCheck.bend, tests/NativeReleaseZeroCheck.bend, tests/native_direct.c

## [ERR-20261003-ZHJ] JavaScript heartbeat fixture stack error

**Logged**: 2026-10-03
**Priority**: medium
**Status**: pending
**Area**: tests

### Summary
Bun and Node could not prepare the 100-KiB editor release heartbeat fixture.

### Error
bend: memory fault (machine stack overflow?)

### Context
Both failed before the first IO diagnostic, before editor load and release
dispatch. Native macOS and Linux completed the same fixture. Do not attribute
this failure to zero-duration sleep or claim JavaScript scheduling coverage.

### Suggested Fix
Isolate fixture generation, UTF-8 encoding, and flat byte conversion. Use an
independent small fixture to check scheduling while the large case is repaired.

### Metadata
- Reproducible: yes
- Related Files: tests/EditorReleaseHeartbeat.bend, tests/EditorReleaseZeroHeartbeat.bend

### Follow-up: large load and fork runtime

The cyclic tail-call fixture generator repaired fixture construction. Tail-call
document assignment then repaired parsing, and a tail-call scene-cache scan
repaired formatted-editor creation. Node passed the complete 100-KiB load probe
on macOS and Linux. The heartbeat case now prepares history but fails at fork
with `Cannot find module 'bun:ffi'`. This runtime dependency must be addressed
before claiming Node fork scheduling support. Bun supplies separate evidence.

### Follow-up: one-MiB Bun formatted-editor construction

The real one-MiB file-open test passed native Bend on macOS and Linux but failed
on Bun on both platforms. Stage diagnostics isolated one failure to the block
parser's final List.append. Tail-call reversal repaired that stage; document
parsing now passes. Formatted-editor creation still fails. The large Bun test
is excluded from the passing batch. The architect reviewed the parser and index
count changes and found no order or count error. Next: isolate scene scan,
cache construction, and scene-index construction. This remains unresolved.

### Resolution for the one-MiB Bun file check

The staged scene probe found non-tail Base List.length calls in bulk-cache
construction and scene-index reuse. Tail-call counts repaired both stages.
The full test then failed in Document.source_list; tail-call character
accumulation and a final reversal repaired source reconstruction. The architect
reviewed each change. The complete real one-MiB file test now passes on Bun on
macOS and Linux, and its batch entry is restored. This resolves that Bun case;
it does not establish large Node behavior or large piece-list reconstruction.
# Startup environment effect

## Pure file-boundary proof imports

The first `ResolvedOpen` module included its foreign host-read wrapper. Adding
that module to LAWS made the standard proof gate reject the foreign definitions.
Move the effect composition into `ResolvedFile`; keep `ResolvedOpen` pure. The
standard proof check then passed. Keep host verification separate from pure laws.

## History memory regression

### Measured repair

Restoring only the earlier cursor consumption in a temporary Linux copy reduced
peak RSS to 236,500 KiB. Bounded dispatch uses that recursive path for at most
128 visible scalars and keeps tail consumption for longer input. Exact boundary
and long-map tests passed. After adoption, the unchanged history gate passed at
242,843,648 bytes on macOS and 242,155,520 bytes on Linux. The runtime cause of
the earlier increase remains unknown; no compiler defect is established.

After long-paragraph stack repairs, the Linux complete batch failed the 300-MiB
history gate at 1,087,680,512 bytes. An isolated current-source run reproduced
the failure at 1,087,959,040 bytes. Preserve the gate and use existing edit,
undo, and all modes to find the stage. The architect requires controlled
temporary-copy comparisons to distinguish extra temporary allocation from
retained history. Do not infer a cause from the peak alone.

The app's Node no-input run failed because Base `IO.get_env` loads `bun:ffi`.
The separate `OpenConfig` effect now reads only `MARKBEND_OPEN_PATH`. Native
code returns raw bytes for strict Bend decoding. JavaScript uses `process.env`.
During implementation, helper order and the reusable Maybe type caused compiler
errors. The JavaScript list also used incorrect field names; the Unicode test
found this error. The corrected list uses `head` and `tail`. Automated checks
now cover missing, empty, Unicode, invalid native bytes, and host string errors.

## [ERR-20261003-U01] Native startup test Unit constructor

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

The native startup driver did not compile. `io_node` needs four arguments;
it is not the constructor for a field-free Unit value. Use the existing native
driver pattern, `term_pak(CID(Unit), 0)`. Check an existing effect before adding
a runtime constructor call.

The first startup window test remained open after `performClose:nil` on its
alert window. The modal delegate did not receive a close event. The driver now
calls `windowShouldClose:` to send the normal close event. A global-queue
watchdog bounds startup independently of the modal run loop. The complete
accepted and rejected native startup checks passed after this correction.

The test-only effect override also failed to compile: foreign CID substitution
did not resolve imported `LiveParagraph.open` under either attempted alias.
The native key-window notification did not trigger before the timer in the
negative control. The test now intercepts `makeKeyAndOrderFront:` in its own
process. It checks rejection mode before calling the original implementation.
This keeps the production effect unchanged and detects the display call
without timer polling. The accepted path restores the original method.

The resolved callback test needed explicit String annotations on reusable
literal locals. Its invalid scalar fixture then failed on JavaScript before
the editor callback: both Char.from_u32 and Chr lower to the checked JavaScript
character constructor. A test-only foreign effect now creates one unpaired
surrogate directly. Native code builds the exact SCon value with a raw scalar
field. The test first checks that Utf8.encode rejects the value, then checks
that local and full-source callbacks preserve the document on rejection.

The native callback build also failed when the compiler removed an unused
LiveParagraph.next effect identifier. The C host registered every effect
without checking whether its identifier remained. Registrations now use the
same conditional CID guards as the installed Bend file and window effects.

The initial recovery fixture first failed Bend syntax checks because it matched
a computed value and placed a match inside an IO block. Use separate helper
definitions for these matches. Exact catalog assertions also needed a reusable
catalog field because both cleanliness and full equality consume it. The
corrected fixture passes native, Bun, and Node checks on macOS and Linux.

The resolved restart fixture repeatedly failed a combined mode-string and
catalog match with "a match on a parameter or field" at the catalog scrutinee.
Reusable entry annotations, a reusable catalog parameter, and a parameter
rename did not fix it. Separate helpers now match the mode, catalog, and plan
one at a time, with the same exact assertions. A helper definition also had to
move before its caller. Native and Bun restart checks pass on both platforms.
The repeated diagnostic does not establish a compiler defect.

The recovery configuration effect returned a JavaScript constructor object for
Bool. This runtime uses plain JavaScript booleans, so the false object appeared
true. Exact Node capability tests found the error. The effect now returns the
primitive boolean. Host tests assert its exact type and value.

The startup fixture precreated an empty catalog entry, so the supposed empty
catalog required review. Create the entry only before the writer starts. Also,
unset removed the root variable's export attribute. Restore it with export.
These fixes preserve the configuration assertions rather than weakening them.

The Linux startup check first verified only process status. Review required an
exact source check. Terminal output used %.*s and stopped at embedded NUL.
Length-aware fwrite now prints complete source and preview bytes. The checker
compares the full source and following terminal boundary. Startup checks pass
for restored source, NUL, and blocked cases on native Linux.
## [ERR-20261003-TCF] Split terminal checkpoint

**Priority**: high
**Status**: in_progress
**Area**: tests

The full Linux batch failed because the driver counted a new checkpoint header
but read the previous source. The architect confirmed the framing error.
The parser now requires source and suffix after the current header. A byte-split
test covers Unicode and NUL. Repeat the staged Linux test before closure.

## [ERR-20261003-IWD] Input wait declaration

**Priority**: medium
**Status**: pending
**Area**: backend

The macOS InputWait native build failed because getentropy was not declared.
The host prototype remains unconnected. Check platform declarations before
testing the native service.
## [ERR-20261003-IWR] Wake channel reset

**Priority**: medium
**Status**: resolved
**Area**: tests

Linux reports ECONNRESET when a wake channel closes with an unread extra byte.
The Node fixture had no error handler for its notice channel. Both private
channels now handle reset. Child success, exact notice count, and retained-state
output remain required. All seven Linux cases then passed.

## [ERR-20261003-DCC] Docker batch connection canceled

**Priority**: medium
**Status**: pending
**Area**: infra

The full Linux retry ended with status 125 and a canceled Docker client
connection. The subsequent container list was empty. Do not count it as passed.
The next isolated native host test ran successfully. A full retry is required.
## [ERR-20261003-IWA] Generated runtime sanitizer failure

**Priority**: medium
**Status**: pending
**Area**: tests

The generated InputWait Bend binary with address/undefined sanitizers failed
in corpus_eval on the first resume case. The standalone host engine sanitizer
checks passed. The cause is not established. This failed check does not prove
work-object cleanup. Use a focused allocation-count fixture and investigate
the generated-runtime failure separately.
## [ERR-20261003-MPE] Native pending fixture observation

**Priority**: medium
**Status**: resolved
**Area**: tests

The generic EOF observer required stderr status from the macOS native adapter.
That adapter uses an alert field, not stderr. The synthetic pending fixture also
does not create the alert through next. Restrict this terminal observer to Linux;
keep macOS pending-state coverage in the pure model and Node/Bun paths. Do not
claim native macOS EOF observation coverage from this fixture.
## [ERR-20261003-ICT] Idle CPU assertion

**Priority**: medium
**Status**: in_progress
**Area**: tests

The macOS Bun retained suspension observation measured 0.01 seconds of CPU time
over 1.5 seconds. Exact equality failed. The requirement is low idle CPU, not
zero measured activity. The gate now allows 0.05 seconds plus numeric rounding;
it still rejects busy polling. RSS growth remains bounded at 4 MiB. Repeat
the macOS batch and retain this measured scope in the experiment document.
## [ERR-20261003-REC] Recovery fixture EOF now suspends

**Priority**: high
**Status**: in_progress
**Area**: tests

Both full EOF batches parked in the Bun recovery startup fixture. Its callback
returned null after source validation. That is now input-ended, not Close.
The exact owned parked children were terminated, and both batches ended 143.
The fixture now sends explicit Close then Discard only when dirty, rejects extra
prompts, and registers count/disk assertions before generated process exit.
An external watchdog fails with 124; rejection checks cannot accept that timeout.
Focused startup reruns and fresh full batches remain required.
## [ERR-20261003-NGH] Injected generated C feature headers

**Priority**: medium
**Status**: resolved
**Area**: tests

The Linux target swap build used -include before the generated runtime's GNU
feature definition. sched_getaffinity and CPU_COUNT were not declared. Define
_GNU_SOURCE before the injected header's system includes. The normal native
effect and engine had already passed. Rerun the complete target batch.

The complete Linux target batch then passed, including the actual effect
parent-replacement case. The macOS batch also passed.

## [ERR-20261003-NSP] Native Save As panel confirmation fixture

**Priority**: medium
**Status**: in_progress
**Area**: tests

The real NSSavePanel fixture repeatedly opened and cancelled correctly, then
timed out after programmatic confirmation. Directory and name fields changed,
but panel.URL retained a remembered path. Field-setting timing and waiting for
the pre-confirmation URL did not solve the failure. A test-only selected-path
guard now aborts before resolution unless the selected path is the exact private
fixture. No failed run is passing evidence. Computer Use inspection failed with
native pipe startup unavailable. Keep real panel confirmation as an open check;
host publication and terminal app checks cannot replace it.

A test-only preparation hook before runModal now sets the exact private URL.
The revised run still failed at step 3: directory, name, and URL were correct,
but the recursive view search found no Save NSButton. The panel may use a
remote view. This is a test control limitation; no publication was accepted.
Review use of the public panel confirmation action after committing the field
editor. Keep the exact selected-path guard and real runModal result.

The public ok: retry also failed at step 4 after 25 seconds. Its path was exact;
the first responder was NSRemoteView for the AppKit open/save panel service.
The panel did not return to the app. No confirmation claim is valid. Review a
real remote-panel input method before another run.

A Return key-down/key-up pair through NSApp sendEvent also failed at step 4
with the exact target and remote view. The native UI tool was checked again;
getState returned no apps and reported native pipe startup failure. Real panel
confirmation remains unverified. Other experiments can continue.

## [ERR-20261003-NRB] native Return benchmark initialization

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
The new native Return benchmark checked text views before native initialization.

### Error
`source=1 raw=0 scene=0 caret=0 visible_length=0 selection_length=0`

### Context
Two small-fixture runs failed before the first Return. LiveParagraph.next
creates the native controls. Presentation before that call stores the scene,
but it cannot supply a visible editor. The first build also rejected a tuple
let binding with a reusable field. Remove that binding or use a match helper.

### Suggested Fix
Send one unmeasured unchanged-selection event through the real event loop.
Then verify source, scene, selection, layout, and viewport before timing Return.
Keep all 20 measured Return events. The architect approved this correction.

### Metadata
- Reproducible: yes
- Related Files: tests/NativeReturnBench.bend, tests/native_return_bench.c

### Resolution
The architect approved one unmeasured unchanged-selection event. Initialization
now checks empty edit histories and clean saved state. The first layout also
exposed a scrollbar width change after Return. The benchmark now uses a fixed
visible legacy scroller and restores the recorded clip-view bounds after undo.
All six corrected batches passed, with 20 measured Return events in each.
Exact checks include result-caret visibility. No product adapter change was
needed. Results and measurement limits are recorded in BENCHMARKS.md.

## [ERR-20261003-NRP] native Return patch reference helper

**Logged**: 2026-10-03
**Priority**: high
**Status**: resolved
**Area**: tests

### Summary
The new reference helper compared a runtime tag with a constructor identifier.

### Error
`while (term_tag(runs) != CID(Nil))` did not terminate after consuming runs.

### Context
The standalone native test used CPU without a result. The macOS batch was
started while its handle was still live and reached the same native test.
Both native processes and the macOS batch were stopped with TERM. Their
handles returned 143. The isolated Linux pure batch continued and passed.
Earlier build corrections added the missing proof import, reused quantities,
affine callback wrappers, and the reachable Driver.inspect effect.

### Suggested Fix
Use the existing production pattern `term_aux(runs) == CID(Con)`, check Nil
after the loop, and bound the short fixture's run count. Use the external
watchdog because a modal timer cannot interrupt a blocked C effect. Require
the standalone native process to finish before starting a native batch.

### Metadata
- Reproducible: yes
- Related Files: tests/native_return_patch.c, tests/NativeReturnPatchCheck.bend,
  tests/list_return.sh, PROOF.bend

### Resolution
The architect approved the existing Con traversal and typed arity guard.
The corrected standalone passed with an external 30-second watchdog and
exit 0 before the macOS batch restarted. The helper bounds short fixture
runs, checks Nil termination, and rejects invalid UTF-8. It checks Run shape,
not arbitrary malformed runtime terms. The permanent native test now uses
the external watchdog. No production host change was needed for this error.

## [ERR-20261003-TRM] Long-item reference check and record patch

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The new Bend reference helper initially omitted the IO.pure type argument and
the reusable quantity for the twice-used position. Documentation patches also
used a nonexistent context line and failed repeatedly.

### Error
`expected : Type; observed : Window` and `position (consumed more than once)`.
`apply_patch verification failed: Failed to find expected lines`.

### Resolution
Use `IO.pure(Window, window)` and `+position`. The corrected native benchmark
build returned exit 0. Read the exact current file tail before applying a
separate documentation patch. The architect reviewed the corrected helper.

### Metadata
- Reproducible: yes
- Related Files: tests/NativeReturnBench.bend, LAWS.bend, .learnings/ERRORS.md

## [ERR-20261003-TIM] Return timing overlapped a Linux batch

**Logged**: 2026-10-03
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
The native timing run overlapped the Docker application batch on the same
computer. Its timing samples cannot support the isolated baseline comparison.

### Context
Session 40363 ran the native benchmark. Session 4405 ran the Linux batch.
The first three uninstrumented fixtures passed their exact checks before the
driver was stopped with TERM. Session 40363 returned 143. The large child had
already exited before its TERM command; a process check found no remaining
native benchmark process. The instrumented batch did not complete.

### Suggested Fix
Run application checks first. Require all their exact handles to return a
terminal result before starting the native timing batch. Keep the interrupted
log, but do not use its samples as the performance result.

### Metadata
- Related Files: tests/native_return_bench.mjs, BENCHMARKS.md
- Evidence: /tmp/markbend-native-return-trim-batch.log

### Resolution
Both final source-layout platform handles returned 0 before the isolated
native timing run started. No other MarkBend test or benchmark process ran
with it. All six cases and 120 samples passed, handle 95440 returned 0, and
the complete results are retained in BENCHMARKS.md. The interrupted run stays
excluded from the comparison.

## [ERR-20261003-NDS] Native document source assertion before the source move

**Logged**: 2026-10-03
**Priority**: high
**Status**: in_progress
**Area**: tests

### Summary
The pre-move macOS full gate, session 10950, returned 1 at the exact native
document source assertion. The source move started only after that result.
The Linux full gate, session 4405, returned 0.

### Error
`Native source range update failed`.

### Context
The full gate redirects the warm and cold native document outputs into its
temporary directory, which its exit trap removes. The earlier message did not
identify the edit count, source lengths, or raw-editor equality.

### Suggested Fix
Keep the exact assertion. Report edit count, actual and expected source length,
raw-editor equality, and the first prefix mismatch. The architect advises
checking selection, input range/text, pending projection, and the supplied
source replacement if the failure repeats. Compare identical temporary copies
with and without trimming before assigning a cause.

### Resolution evidence so far
After the path-only move, the focused warm native check, session 3596, returned
0. The focused cold check also returned 0. Complete macOS and Linux gates from
the new layout then returned 0 (handles 11837 and 24923). These results do not
explain the earlier failure. Keep it open. The architect approved the isolated
timing experiment with this uncertainty retained and instructed stopping it
if the source failure repeats.

### Metadata
- Related Files: tests/native_document.c, tests/NativeDocumentBench.bend
- Evidence: /tmp/markbend-trim-macos-full.log

## [ERR-20261003-SYN] POSIX host syntax invocation on macOS

**Logged**: 2026-10-03
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
Plain C syntax checking on macOS selected the Apple Objective-C branch.

### Error
C compilation reported Objective-C declarations such as `@class` as invalid.

### Resolution
Use the documented `clang -U__APPLE__ -D__linux__ -std=c11 -fsyntax-only
tests/linux_host_syntax.c`. That command passed. Check the native Apple branch
with Objective-C and Cocoa; that host test also passed. The initial C command
did not prove POSIX syntax.

## [ERR-20261004-PFX] Time Profiler table includes missing stacks

**Logged**: 2026-10-04
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The first XML summary assumed every CPU sample had a backtrace. Five rows
contained a sentinel instead, so the parser raised StopIteration.

### Resolution
Resolve exported ID references, check for a backtrace, and count sentinel
samples as unknown. The corrected summary counted all 6,916 target samples,
including the five missing stacks. Do not discard these rows or assign them
to a known function. The profile includes untimed checks and undo; aggregate
counts do not establish Return-phase costs.

### Metadata
- Evidence: /tmp/markbend-return-profile.xN3mUc/time-profile.xml

## [ERR-20261004-KRN] Return kernel fixture compilation

**Logged**: 2026-10-04
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The new kernel fixture first put a `match` inside an IO block. Bend requires
it at the head of a definition. A later build found an affine tree used twice.

### Resolution
Move result destructuring into helper definitions. Mark the tree and scene
result reusable where count checks need two reads. The corrected native build
returned 0. The architect found an extra retained changed document before
the document kernel. Prepare that value only after document timing finishes.
The corrected driver returned 0 with all 40 exact kernel checks passing.

### Metadata
- Related Files: tests/ReturnKernelBench.bend

## [ERR-20261004-WPF] Width-consumer proof draft

**Logged**: 2026-10-04
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
The temporary universal width/remainder proof does not yet check. The first
draft put definitions before remaining imports. Later drafts could not reduce
overlapping character matches, even with a literal False plain flag.

### Context
The loop rule compares the width-only scan with the width and remainder of
`Cursor.consume_loop`, for all visible/source lists, offsets, flags, and
position accumulators. Existing character-first matching prevents reduction
when character heads remain unknown. Matching a later parameter also prevents
a later match on earlier binders; moving the flag first fixed that binder error.

### Suggested Fix
Review the proof structure with the architect. Do not weaken the universal
rule or change the mapping consumer merely to make a proof check. The proof
draft remains in the temporary copy; application source is unchanged.

### Resolution
The architect reviewed a finite proof-only bit-prefix tree for character
values 42, 96, and 92. Mismatch leaves retain arbitrary Word suffixes. Both
loop and short-scan theorems passed the standard Bend proof check. A shared
width helper then allowed dispatch and complete Part equivalence to check.
The flag is last in the trie theorem, so nested character matches do not
consume it before the exact-escape Boolean split. The generator reproduces
both full proof files. Root `bend PROOF.bend` passed after integration.
Cursor matching and the universal contract were not changed to obtain this
result. Application gates remain separate from this proof-error resolution.

### Metadata
- Related Files: /tmp/markbend-projection-control.5bSUwp/LAWS.bend
- Related Files: /tmp/markbend-projection-control.5bSUwp/PROOF.bend

## [ERR-20261004-RMP] Reversed mapping memory regression

**Logged**: 2026-10-04
**Priority**: high
**Status**: in_progress
**Area**: performance

### Summary
The temporary long-run mapping control removes two position-list reversals
and passes complete-result checks and standard proofs. It lowers matched
command medians from about 47 ms to 29 ms, but increases whole-process peak
memory from about 186 MB to 402 MB. The generic history gate fails at
1,088,765,952 bytes against the unchanged 300 MiB limit.

### Context
Public consumers and bounded short dispatch are unchanged. The control uses
a separate reversed-position result only in long mapping construction.
All 160 matched checks passed. This does not prove good ownership behavior.
Peak measurements include verification and Undo outside timed commands.
No specific retained object or runtime allocation cause has been established.

### Next action
Do not adopt the candidate. Follow the architect's review: measure fresh
control and variant processes at 1, 5, 10, and 20 operations in both ownership
modes, with external resident-memory observations aligned to sample output.
Then inspect allocation in the smallest reproducing case. Keep complete
checks and the memory limit unchanged. Production source remains unchanged
by this candidate.

### Metadata
- Related Files: /tmp/markbend-reverse-control.1UymVV/src/CursorMap.bend
- Related Files: /tmp/markbend-reverse-control.1UymVV/matched.log
- Related Files: /tmp/markbend-reverse-control.1UymVV/history-memory.log

### Follow-up evidence
The reduced inactive-projection fixture exposes a missing text release in the
rejected generated mapping shape. A C causal diagnostic balances its counters.
This does not establish a general compiler defect. The temporary Bend-owned
work record also balances all tracked allocation classes in six plain cases,
24 style cases, and six many-run inputs. The many-run peaks show no added
cost against the original control in the tested inputs.

The separate application snapshot `/tmp/markbend-owned-app.LIpm1u` passes the
complete build-equivalence proof with Bend's checker. Its history memory gate
passes at 242,810,880 bytes; its document gate passes at 79,396,864 bytes.
The independent kernel check remains unavailable because Lean is absent.
Full platform checks and matched Return timing remain open. The production
candidate is not adopted. Keep the original memory limits.

## [ERR-20261004-SNAPSHOT-GIT] Isolated batch lacks Git metadata

The owned-candidate macOS batch passed its runtime checks, then returned 129
at the final git diff --check. The copied snapshot did not include a Git
repository. Create snapshot Git metadata before a full runner that requires it.
Do not change the runner or omit its final gate. Snapshot git init and staging
followed by cached and ordinary whitespace checks returned 0. A fresh complete
batch remains required. No production source change was needed.

Evidence: /tmp/markbend-owned-macos-full.log and
/tmp/markbend-owned-app.LIpm1u.

## [ERR-20261004-SCAN-CAUSAL] One scoped scan release does not balance

**Priority**: medium
**Status**: in_progress
**Area**: tests

The first C causal diagnostic releases the saved source in the inspected
scan-loop continuation after successful borrowed scalar counting. The single
paragraph scan still leaves 98,304 tracked bytes. The native process exits
zero and all semantic checks pass; the driver's balance assertion fails.
Do not treat a plausible ownership site as the complete cause. Check whether
the patched path executes and inspect compiler-expanded caller paths before
adding more releases. Keep the failed raw logs in the diagnostic directory.

Evidence: /tmp/markbend-verify-memory.XITNkA/causal-first-single-scan-one.stderr.log.

## [ERR-20261004-VERSION] Opening scan fails with host Bend 2.0.35

**Priority**: high
**Status**: in_progress
**Area**: tests

The full candidate batch stops at OpeningScanCheck. The unchanged control
also fails with Bend 2.0.35 at default and four-thread settings. LLDB shows
EXC_BAD_ACCESS in WL_FID_LIST_APPEND. Both builds pass with a verified local
Bend 2.0.34 archive at both thread settings. This establishes a
version-dependent fixture failure, but does not establish its runtime cause.

Record the compiler version and binary hash before comparison tests. Use the
local pinned toolchain for the required candidate gates. Keep the host
installation unchanged and preserve the failed logs. Earlier results with an
unrecorded version must not be used as one complete gate.

Evidence: /tmp/markbend-toolchain-2.0.34.1eI31E/COMPARISON.md.

## [ERR-20261004-BALANCE] Output success was reported as allocation balance

**Priority**: high
**Status**: in_progress
**Area**: tests

The candidate whole-check observer reports output success but does not assert
zero retained bytes. Its old and new raw records both show 50,331,648 retained
bytes after one check and 150,994,944 after five checks. The earlier report of
balanced whole-check counts was incorrect. The generated mapping ownership
code matches in the two inspected candidate C files. Do not attribute this
retention to the compiler version without other evidence.

The report is corrected. The local whole-check runner now has a separate
--require-balance assertion. The fresh-case runner asserts zero retained bytes
and zero outstanding wrappers. Pause candidate adoption and native profiling.
Run the isolated view components with the pinned compiler to locate the
remaining retention path.

Evidence: /tmp/markbend-projection-owned.RW228O/wrappers-observations.json and
/tmp/markbend-projection-owned.RW228O/2034-wrappers-observations.json.

## [ERR-20261004-SAV] native_save_exact_source

**Logged**: 2026-10-04
**Priority**: high
**Status**: monitored
**Area**: tests

### Summary
The fresh macOS batch fails the exact source check after Apply in the native
Save fixture. The host source has one extra terminal newline.

### Error
Native app save failed at step 1: exact source bytes. Actual source is 21
bytes; expected source is 20 bytes. Actual hexadecimal bytes end in 000a0a;
expected bytes end in 000a.

### Context
Pinned Bend 2.0.34, frozen cleanup tree
cc0806ca83d76c01946fcdb31fbadca04de73dcb. Full Linux and native cleanup
checks pass, but they do not establish this Save workflow. The macOS batch
returns 1. Preserve /tmp/markbend-cleanup-final-macos.log. Adoption stays
unapplied. Run fresh sequential control/candidate Save checks before
assigning a cause. Keep the exact byte assertion.

Fresh unchanged control and repaired binaries pass all four Save modes.
Five further sequential control/repair normal-mode pairs pass with byte
traces at the editor, Apply capture, and Bend presentation. All ten retain
the exact expected twenty bytes. The failure remains unreproduced with cause
unknown. The architect approved one exact-tree full macOS repeat. No byte
assertion, production behavior, or timer wait was changed.

The unchanged full macOS repeat returns zero and passes all six Save
sequences. Its log is /tmp/markbend-cleanup-final-macos-repeat.log. The
architect approves the cleanup repair after this result. The first failure
has no established cause or fix. Keep its failed log and exact assertions.

### Metadata
- Reproducible: unknown
- Related Files: tests/native_app_save.c, src/live_paragraph.c

---
## [ERR-20261004-NAV-UI] Native Save As verification interrupted

CUA returned noWindowsAvailable, then timeoutReached after Save As input in
the separate Navigation QA app. No saved fixture exists. Earlier native
navigation checks passed. The architect found no evidence of a source defect.
Stop UI calls and retain the automated invalid-regex check. Do not report the
interrupted native save or exact-byte comparison as passed.
## [ERR-20261004-BLOCK-TYPES] DOM collection test types

The new block preview tests used spread syntax on NodeList. The project TS
library set omits DOM.Iterable, so type checking rejected four expressions.
Use Array.from, consistent with the existing tests. The source tests pass;
the desktop build also runs the type check.
## [ERR-20261004-PREVIEW-PADDING] CodeMirror base style priority

The native screenshot showed text and quote borders at the window edge.
CodeMirror's generated base selector has more priority than .cm-content,
so the writing-area padding was lost. Scope content styles through editor
and scroller classes. Give the cell content override one more class. Verify
the final native layout before reporting the correction as checked.
The final MarkBend bundle confirms the writing margins and cell padding.
The architect found that the stronger content selector also overrode Source
mode's monospace font. Keep only padding in the stronger rule; leave font
choice in its original rule. Check Source mode and cell fonts after rebuilding.
The final Fonts QA app confirms Source and cell monospace fonts, preview serif
font, and both padding sizes. The architect correction is verified.
## [ERR-20261004-DISK] Source write failed with full disk

apply_patch could not create formatting.ts. df showed only 120 MiB free.
Removed only this project's generated target/debug/incremental Rust cache.
It can be regenerated. Source write then passed. Keep further builds bounded
and disable incremental Rust output for the current check.
## [ERR-20261004-FORMAT-TEST] Unreleased CodeMirror test views

The new formatting tests created several views in case loops and destroyed
only the final view. Their pending layout frames hit JSDOM's missing Range
measurement API. Destroy the previous view and clear its DOM before creating
the next case. Do not suppress unhandled errors or count that failed run as
passed. The corrected batch must pass before native checks.
The corrected 76-check batch passes without unhandled errors.
## [ERR-20261004-FORMAT-NESTED] Nested emphasis delimiter ambiguity

The native Italic shortcut inside Bold rejected the generated triple-star
span because the parser assigned different delimiter ranges. Try the alternate
underscore delimiter and validate its exact requested parsed span before
dispatch. The new nested-style test checks one-step Undo/Redo and removal of
Italic while keeping Bold. Rejected candidates do not change source/history.
The full 77-check batch and native nested-style/Undo/Redo checks pass.
## [ERR-20261004-FORMAT-AX] Native text selection was unavailable

CUA could not select the pasted Unicode text before a fresh AX observation.
The next observation confirmed the fixture was present. Used native keyboard
selection instead, preserving Japanese characters and the emoji as clusters.
The formatting and saved-byte checks then passed. Do not count the failed AX
selection attempt as an input check.
## [ERR-20261004-LINK-SPACING] Link field boundary test assumption

The first link batch expected a link with a newline between URL and title to
be rejected. Its fields are single-line, and the source patches safely retain
that separator. Test multiline labels as unsupported instead, and verify exact
retention of mixed-ending URL/title spacing through edit and Undo. Do not reject
a valid retained source range merely to satisfy the initial test assumption.
## [ERR-20261004-LINK-BOUNDARIES] Raw angles and form Escape

The extra destination test assumed raw angle brackets could be escaped into
an accepted URL. Complete candidate validation rejected that spelling. The
architect confirmed the rejection; use %3C/%3E and retain parser validation.
The architect also found Escape could close the form during composition.
Defer Escape for the local composition flag or KeyboardEvent.isComposing.
Regressions check both flags, exact source/history, and encoded destinations.
## [ERR-20261004-LINK-WINDOW] Link QA window selection failed

CUA reported cgWindowNotFound for the Link QA bundle path, identifier, and
display name. The owned process remained live. Host logs show a visible but
occluded window at startup. This does not prove a link defect or a closed
window. Stop selection retries. Preserve other apps and documents, record the
native evidence gap, and do not add a reopen handler from this observation.
## [ERR-20261004-THEME] Test types and CodeMirror color precedence

The contrast test passed at runtime but its node:fs import failed the project
TypeScript check. Import the CSS through Vite's typed raw import instead.
Architect review also found that CodeMirror's generated light theme can override
the palette. Scope palette overrides under #app for panels, text fields, button
gradients, gutters, active lines, and search matches. Runtime checks alone did
not prove these style rules or the TypeScript build. Vitest's CSS stubbing also
returned an empty raw CSS import. Use node:fs with an explicit @types/node
development dependency for the static contrast check. Keep browser visual
checks separate from that static rule check.
## [ERR-20261004-RETURN-CR] Flat Return did not recognize bare CR

The mixed-ending Return test found that the Bend line scanner treats bare CR
as text. Pass the normalized edit surface to Bend, map scalar ranges to the
source record, and spell inserted endings from the current raw source line.
Do not normalize the saved source. Check exact Undo/Redo and Unicode positions.
The package's high-priority Markdown Enter binding also bypassed the app
command. Disable its automatic keymap and retain the other Markdown bindings
after the app's guarded Return. Check actual key events, not only direct calls.
## [ERR-20261004-EDITOR-PERFORMANCE] Benchmark and cache eligibility

Benchmark replacements must differ from the fixture character. A long synchronous
batch can starve Vitest's progress transport; yield between samples off clock.
ASCII-only edits can change Markdown structure near list and inline delimiters.
Reuse note structure only inside an ASCII word with unchanged guards on both
sides, checked against every change. Use UTF-16 positions, not scalar indexes.
Compare cached models and rendered definitions with a cache-free parser oracle.

## [ERR-20261004-QUIT] Module reset and StateField identity

The renderer-restart test resets modules. Its old sourceField import cannot read
the new EditorState because StateField identity changes. Read the new module's
field after reset. Keep the startup-event/token race test; do not drop its source
and input-lock assertions to avoid the identity error.

## [ERR-20261004-FOOTNOTE-MATH] DOM iteration and text layout

The TypeScript DOM library does not enable iterable NodeList. Use Array.from.
The async footnote formula checks also reached CodeMirror text measurement;
jsdom lacks Range geometry methods. Supply empty geometry in these source/history
checks and check actual formula layout in the browser. Do not treat a passing
test with an unhandled layout exception as valid evidence.

## [ERR-20261004-FOOTNOTE-COMMANDS] Typed cell fixture and packaging

The cell guard fixture used tableFrom/tableTo instead of the ActiveCell contract.
Vitest passed, but TypeScript rejected it. Use from/to with cellFrom/cellTo and
run the type check. The macOS DMG build failed in its Finder script after the
app built. The app-only bundle passed. Keep DMG packaging unverified rather than
retrying the same UI script as an input acceptance check.

## [ERR-20261004-FOOTNOTES] Parser context and unresolved references

Lezer can mark an unresolved footnote as a shortcut link. Keep its brackets in
preview. A script tag at the start of a definition creates an HTML block, so its
remaining Markdown is literal text. Use paragraph context to check inline HTML,
links, images, and math. Do not change package parsing to fit the test fixture.

## [ERR-20261004-RECOVERY] Recovery confirmation and native checks

Architect review found that clear retries skipped directory confirmation on
NotFound, empty renderer starts reused tokens, and path checks did not validate
opened descriptors. Correct all three and test failure/retry and stale tokens.
Lease contention must be separate from read errors. A pure input debounce can
postpone recovery indefinitely, so add a maximum scheduling interval.
The isolated Recovery QA build passed, but CUA reported cgWindowNotFound on
selection. Stop UI retries and keep native recovery acceptance unverified.
A later Rust test edit used a JavaScript-style comma between let bindings;
cargo fmt rejected it. Use separate Rust declarations and rerun the full checks.
# [ERR-20261004-FILE-KEYS] Table keyboard propagation

The first file-shortcut integration check failed in a table cell. Its widget
stops key bubbling. Capture only the three recognized native file shortcuts at
the document, consume those events, and keep ordinary Save and input keys on
their existing routes. The repeated focused check and full suite passed.
# [ERR-20261004-DOCUMENT-PATH] Match the host path contract in save tests

The duplicate-document test passed a temporary-directory alias directly to the
shared save function after Open canonicalized it. On macOS /var can resolve to
/private/var. The IPC Save command canonicalizes paths before this function.
Canonicalize the fixture too; retain the production destination checks.

## [ERR-20261004-PRINT-VIEW] Print checks and isolated diagram styles

**Logged**: 2026-10-04T13:16:00Z
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
Print view checks exposed a DOM test gap and missing Mermaid styles.

### Error
The DOM fixture reported `showModal does not exist`. A URL spy with no declared
argument caused TypeScript tuple error TS2493. Removing Mermaid's style element
produced black diagram boxes in the Chrome visual check. A patch with two update
entries for one file was rejected before it changed files.

### Context
The print view uses a native dialog and async renderer resources. The DOM test
environment has no dialog implementation. Browser Print then timed out on its
input command; native Chrome inspection returned `cgWindowNotFound`.

### Suggested Fix
Provide an explicit test-only dialog method and typed URL spy. Keep Mermaid
styles inside an isolated SVG image, wait for image load, and revoke each URL.
Use one update entry per file in a patch. Do not infer native Print acceptance
from the DOM checks. Close the owned browser tab after the failed native check.

### Metadata
- Reproducible: yes
- Related Files: src/web/print-view.ts, tests/web/print-view.test.ts

### Resolution
- **Resolved**: 2026-10-04T13:16:00Z
- **Notes**: Diagram and DOM fixes pass focused checks. Native Print stays unverified.

## [ERR-20261004-PNG-CHECK] PNG types and browser file verification

**Logged**: 2026-10-04T13:40:00Z
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
The rasterizer does not export its Options type, and browser downloads could not
be observed through the current tool.

### Error
TypeScript reported TS2459 for `Options`. Browser download event and image-media
download tracking timed out. Reading the OS Downloads folder was denied.

### Context
PNG capture succeeded in Chrome, but those checks did not prove file placement.

### Suggested Fix
Derive options from the package function signature. Show the generated PNG as a
preview and report only "download requested" in browser mode. Native success
requires the host write acknowledgment. Do not retry protected-folder access.

### Metadata
- Reproducible: yes
- Related Files: src/web/png-export.ts, src/web/print-view.ts

### Resolution
- **Resolved**: 2026-10-04T13:40:00Z
- **Notes**: Type checks pass. A decoded 820 by 701 PNG preview has a visual check;
  file placement and native export acceptance remain unverified.
