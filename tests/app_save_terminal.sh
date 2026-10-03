#!/bin/sh
set -eu
app=$1
save_root=$(mktemp -d /tmp/markbend-app-save-terminal.XXXXXX)
trap 'rm -rf "$save_root"' EXIT HUP INT TERM
save_root=$(cd "$save_root" && pwd -P)
export MARKBEND_OPEN_PATH="$save_root/中文 😀.md"
unset MARKBEND_STARTUP_RECOVERY_HOST MARKBEND_STARTUP_RECOVERY_ROOT
printf 'A\r\n' > "$MARKBEND_OPEN_PATH"
printf '\357\273\277中文😀\r\ne\314\201\000\n' > "$save_root/expected"
{
  cat "$save_root/expected"
  printf '.apply\n.close\n.cancel\n.save\n.undo\n.redo\n.close\n'
} | "$app" > "$save_root/output" 2>&1
cmp "$MARKBEND_OPEN_PATH" "$save_root/expected"
test "$(find "$save_root" -name '.markbend-save-*' | wc -l | tr -d ' ')" = 0
case "$(cat "$save_root/output")" in
  *'Unsaved changes.'*'Saved'*) ;;
  *) cat "$save_root/output" >&2; exit 1 ;;
esac
printf 'A\r\n' > "$MARKBEND_OPEN_PATH"
{
  cat "$save_root/expected"
  printf '.apply\n.close\n.save\n'
} | "$app" > "$save_root/output" 2>&1
cmp "$MARKBEND_OPEN_PATH" "$save_root/expected"
printf 'A\r\n' > "$MARKBEND_OPEN_PATH"
{
  cat "$save_root/expected"
  printf '.apply\n.close\n.discard\n'
} | "$app" > "$save_root/output" 2>&1
printf 'A\r\n' > "$save_root/original"
cmp "$MARKBEND_OPEN_PATH" "$save_root/original"
printf 'Terminal app exact save, Cancel, history, Save on close, and Discard passed\n'
{
  cat "$save_root/expected"
  printf '.apply\n.save\n.close\n.save\n.close\n.cancel\n.undo\n.redo\n.close\n.discard\n'
} | env -u MARKBEND_OPEN_PATH "$app" > "$save_root/untitled-output" 2>&1
cmp "$MARKBEND_OPEN_PATH" "$save_root/original"
test "$(awk '/Save As is unavailable for this document/ { count++ } END { print count+0 }' "$save_root/untitled-output")" = 2
test "$(awk '/^--- MarkBend multiline checkpoint ---$/ { count++ } END { print count+0 }' "$save_root/untitled-output")" = 7
test "$(find "$save_root" -name '.markbend-save-*' | wc -l | tr -d ' ')" = 0
printf 'Terminal untitled Save and Save-on-close retained the editor without writes\n'
