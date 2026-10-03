#!/bin/sh
set -eu
app=$1
save_root=$(mktemp -d /tmp/markbend-app-save-native.XXXXXX)
trap 'rm -rf "$save_root"' EXIT HUP INT TERM
save_root=$(cd "$save_root" && pwd -P)
export MARKBEND_OPEN_PATH="$save_root/中文 😀.md"
export MARKBEND_SAVE_EXPECTED="$save_root/expected"
unset MARKBEND_STARTUP_RECOVERY_HOST MARKBEND_STARTUP_RECOVERY_ROOT
printf '\357\273\277中文😀\r\ne\314\201\000\n' > "$MARKBEND_SAVE_EXPECTED"
for mode in ${2:-normal conflict missing untitled}; do
  printf 'A\r\n' > "$MARKBEND_OPEN_PATH"
  if test "$mode" = untitled; then
    env -u MARKBEND_OPEN_PATH MARKBEND_SAVE_FIXTURE_PATH="$MARKBEND_OPEN_PATH" MARKBEND_SAVE_MODE="$mode" "$app"
  else
    MARKBEND_SAVE_MODE="$mode" "$app"
  fi
  case "$mode" in
    normal|uncertain) cmp "$MARKBEND_OPEN_PATH" "$MARKBEND_SAVE_EXPECTED" ;;
    before|untitled)
      printf 'A\r\n' > "$save_root/original"
      cmp "$MARKBEND_OPEN_PATH" "$save_root/original" ;;
    conflict)
      printf 'external\r\n' > "$save_root/external"
      cmp "$MARKBEND_OPEN_PATH" "$save_root/external" ;;
    missing) test ! -e "$MARKBEND_OPEN_PATH" ;;
  esac
  test "$(find "$save_root" -name '.markbend-save-*' | wc -l | tr -d ' ')" = 0
done
