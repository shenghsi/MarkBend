#!/bin/sh
# Check source history sharing. This is separate from editor idle memory.
set -eu
cd "$(dirname "$0")/.."
history_dir=$(mktemp -d /tmp/markbend-history-memory.XXXXXX)
trap 'rm -rf "$history_dir"' EXIT HUP INT TERM
bend tests/SessionMemoryBench.bend -o "$history_dir/session-memory"
case "$(uname -s)" in
  Darwin)
    /usr/bin/time -l "$history_dir/session-memory" > "$history_dir/samples" 2> "$history_dir/usage"
    peak=$(awk '/maximum resident set size/ {print $1}' "$history_dir/usage")
    ;;
  Linux)
    /usr/bin/time -v "$history_dir/session-memory" > "$history_dir/samples" 2> "$history_dir/usage"
    peak=$(awk '/Maximum resident set size/ {printf "%.0f", $NF * 1024}' "$history_dir/usage")
    ;;
  *)
    echo 'History memory check needs macOS time -l or Linux GNU time -v.' >&2
    exit 1
    ;;
esac
awk '
  /^edit / {if ($2 != "count=" ++edits || $3 != "scalars=" (1048576 + edits)) exit 1; next}
  /^undo / {undos++; if ($2 != "count=" (20 - undos) || $3 != "scalars=" (1048596 - undos)) exit 1; next}
  /^redo / {if ($2 != "count=" ++redos || $3 != "scalars=" (1048576 + redos)) exit 1; next}
  /^Session history memory batch passed$/ {passed++; next}
  {exit 1}
  END {if (edits != 20 || undos != 20 || redos != 20 || passed != 1) exit 1}
' "$history_dir/samples"
test -n "$peak"
if [ "$peak" -gt 314572800 ]; then
  echo "History memory check failed: peak $peak bytes exceeds 300 MiB." >&2
  exit 1
fi
echo "History memory check passed: peak $peak bytes, 20 edits, undo, and redo."
