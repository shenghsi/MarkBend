#!/bin/sh
# Measure the current native macOS adapter. Other GUI adapters are not present.
set -eu
cd "$(dirname "$0")/.."
test "$(uname -s)" = Darwin
native_dir=$(mktemp -d /tmp/markbend-native-bench.XXXXXX)
trap 'rm -rf "$native_dir"' EXIT HUP INT TERM
bend tests/SceneBench.bend -o "$native_dir/scene-bench"
"$native_dir/scene-bench"
bend tests/NativeDocumentBench.bend -o "$native_dir/native-document"
/usr/bin/time -l "$native_dir/native-document"
/usr/bin/time -l "$native_dir/native-document" large
/usr/bin/time -l "$native_dir/native-document" cold
/usr/bin/time -l "$native_dir/native-document" large-cold
bend tests/NativeStoredBench.bend -o "$native_dir/native-stored"
/usr/bin/time -l "$native_dir/native-stored" --threads 1
