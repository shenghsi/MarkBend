#!/bin/sh
# Run the complete rendering batch from the repository root.
set -eu

cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/markbend-check.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT HUP INT TERM

bend PROOF.bend
bend Experiment.bend -o "$check_dir/experiment"
"$check_dir/experiment"
bend tests/CursorCheck.bend -o "$check_dir/cursor-check"
"$check_dir/cursor-check" > "$check_dir/cursor-output.txt"
diff -u tests/cursor_expected.txt "$check_dir/cursor-output.txt"
bend LiveParagraph.bend -o "$check_dir/live-paragraph"
bend LiveParagraph.bend -o "$check_dir/live-paragraph.js"

clang -std=gnu11 -U__APPLE__ -D__linux__ tests/host_roundtrip.c -o "$check_dir/posix-host"
"$check_dir/posix-host"
if [ "$(uname -s)" = Darwin ]; then
  clang -x objective-c -fobjc-arc -framework Cocoa tests/host_roundtrip.c -o "$check_dir/mac-host"
  "$check_dir/mac-host"
fi
if command -v bun >/dev/null 2>&1; then
  bun tests/host_roundtrip.js
else
  node tests/host_roundtrip.js
fi
git diff --check
echo 'Rendering and cursor-mapping batch passed.'
