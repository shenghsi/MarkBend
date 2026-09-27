# Errors

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
