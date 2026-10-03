#!/bin/sh
set -eu
check_dir=$(mktemp -d /tmp/markbend-list-return.XXXXXX)
trap 'rm -r "$check_dir"' EXIT HUP INT TERM
for module in StoredEditorCheck ListReturnCheck IndexedReturnCheck ReturnPreparedCheck ReturnDirectPreparedCheck ReturnCommandCheck ReturnCommandExtendedCheck WorkspaceReturnCheck; do
  bend "tests/$module.bend" -o "$check_dir/$module"
  "$check_dir/$module" --threads 4
  bend "tests/$module.bend" -o "$check_dir/$module.js"
  for runtime in node bun; do
    if command -v "$runtime" >/dev/null 2>&1; then "$runtime" "$check_dir/$module.js"; fi
  done
done
if test "$(uname -s)" = Darwin; then
  bend tests/NativeReturnCheck.bend -o "$check_dir/native-return"
  "$check_dir/native-return"
  bend tests/NativeReturnPatchCheck.bend -o "$check_dir/native-return-patch"
  node tests/watchdog.mjs 30000 "$check_dir/native-return-patch"
  bend tests/NativeDirectReturnPatchCheck.bend -o "$check_dir/native-direct-return-patch"
  node tests/watchdog.mjs 30000 "$check_dir/native-direct-return-patch"
  clang -x objective-c -fobjc-arc -framework Cocoa tests/host_roundtrip.c -o "$check_dir/host"
else
  clang -std=c11 -D_POSIX_C_SOURCE=200809L tests/host_roundtrip.c -o "$check_dir/host"
fi
"$check_dir/host"
for runtime in node bun; do
  if command -v "$runtime" >/dev/null 2>&1; then "$runtime" tests/host_roundtrip.mjs; fi
done
