#!/bin/sh
set -eu
bench_dir=$(mktemp -d /tmp/markbend-return-bench.XXXXXX)
trap 'rm -r "$bench_dir"' EXIT HUP INT TERM
bend tests/ReturnCommandBench.bend -o "$bench_dir/return"
node tests/return_bench.mjs "$bench_dir/return"
