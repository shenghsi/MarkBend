#!/bin/sh
set -eu
test "$(uname -s)" = Darwin
return_native_dir=$(mktemp -d /tmp/markbend-native-return.XXXXXX)
trap 'rm -r "$return_native_dir"' EXIT HUP INT TERM
bend tests/NativeReturnBench.bend -o "$return_native_dir/return"
node tests/native_return_bench.mjs "$return_native_dir/return"
