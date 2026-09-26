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
