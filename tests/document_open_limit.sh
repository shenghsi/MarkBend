#!/bin/sh
set -eu
program=$1
fixture_dir=$(mktemp -d /tmp/markbend-open-limit.XXXXXX)
trap 'rm -rf "$fixture_dir"' EXIT HUP INT TERM
# These are test files in a newly created directory, not user documents.
dd if=/dev/zero of="$fixture_dir/exact" bs=1048576 count=8 2>/dev/null
printf '\377' | dd of="$fixture_dir/exact" bs=1 count=1 conv=notrunc 2>/dev/null
cp "$fixture_dir/exact" "$fixture_dir/exact-before"
dd if=/dev/zero of="$fixture_dir/over" bs=1048576 count=8 2>/dev/null
printf '\000' >> "$fixture_dir/over"
cp "$fixture_dir/over" "$fixture_dir/over-before"
if [ "$#" -gt 1 ]; then
  MARKBEND_OPEN_LIMIT_PATH="$fixture_dir" "$2" "$program"
else
  MARKBEND_OPEN_LIMIT_PATH="$fixture_dir" "$program"
fi
cmp "$fixture_dir/exact" "$fixture_dir/exact-before"
cmp "$fixture_dir/over" "$fixture_dir/over-before"
