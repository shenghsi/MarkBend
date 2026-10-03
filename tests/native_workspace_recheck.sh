#!/bin/sh
set -eu
if test "$(uname -s)" != Darwin; then
  echo 'Native workspace Recheck requires the macOS AppKit adapter.'
  exit 1
fi
check_dir=$(mktemp -d /tmp/markbend-native-recheck.XXXXXX)
trap 'rm -r "$check_dir"' EXIT HUP INT TERM
bend tests/NativeWorkspaceRecheckCheck.bend -o "$check_dir/recheck"
node tests/native_workspace_recheck.mjs "$check_dir/recheck"
