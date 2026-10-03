#!/bin/sh
# This model check detects retained trees. It is not an editor idle-memory test.
set -eu
cd "$(dirname "$0")/.."
memory_dir=$(mktemp -d /tmp/markbend-memory.XXXXXX)
trap 'rm -rf "$memory_dir"' EXIT HUP INT TERM
bend tests/DocumentMemoryBench.bend -o "$memory_dir/document-memory"
case "$(uname -s)" in
  Darwin)
    /usr/bin/time -l "$memory_dir/document-memory" > "$memory_dir/samples" 2> "$memory_dir/usage"
    peak=$(awk '/maximum resident set size/ {print $1}' "$memory_dir/usage")
    ;;
  Linux)
    /usr/bin/time -v "$memory_dir/document-memory" > "$memory_dir/samples" 2> "$memory_dir/usage"
    peak=$(awk '/Maximum resident set size/ {printf "%.0f", $NF * 1024}' "$memory_dir/usage")
    ;;
  *)
    echo 'Memory check needs macOS time -l or Linux GNU time -v.' >&2
    exit 1
    ;;
esac
awk '$2 != "scalars=1048576" || $3 != "blocks=66577" {exit 1}
     END {if (NR != 80) exit 1}' "$memory_dir/samples"
test -n "$peak"
if [ "$peak" -gt 209715200 ]; then
  echo "Document memory check failed: peak $peak bytes exceeds 200 MiB." >&2
  exit 1
fi
echo "Document memory check passed: peak $peak bytes, 20 parse/edit cycles."
