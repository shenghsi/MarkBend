#!/bin/sh
set -eu
check_dir=$(mktemp -d)
trap 'rm -r "$check_dir"' EXIT HUP INT TERM
for module in WorkspaceControlCheck WorkspaceLoopCheck; do
  bend "tests/$module.bend" -o "$check_dir/$module"
  "$check_dir/$module" --threads 4
done
if test "$(uname -s)" = Linux; then
  bend tests/WorkspaceEventCheck.bend -o "$check_dir/events"
  "$check_dir/events"
fi
for module in WorkspaceControlCheck WorkspaceLoopCheck WorkspaceEventCheck; do
  bend "tests/$module.bend" -o "$check_dir/$module.js"
  for runtime in node bun; do
    if command -v "$runtime" >/dev/null 2>&1; then "$runtime" "$check_dir/$module.js"; fi
  done
done
