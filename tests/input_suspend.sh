#!/bin/sh
set -eu
check_dir=$(mktemp -d)
trap 'rm -r "$check_dir"' EXIT HUP INT TERM
node tests/input_suspend_capability.mjs
clang -std=gnu11 -U__APPLE__ -D__linux__ -fsanitize=address,undefined tests/terminal_draft.c -o "$check_dir/draft"
"$check_dir/draft"
bend tests/AppPendingInputCheck.bend -o "$check_dir/pending"
if [ "$(uname -s)" = Linux ]; then
  node tests/input_suspend_host.mjs native "$check_dir/pending" pending
fi
bend tests/AppPendingInputCheck.bend -o "$check_dir/pending.js"
bend src/LiveParagraph.bend -o "$check_dir/app.js"
for runtime in node bun; do
  if command -v "$runtime" >/dev/null 2>&1; then
    node tests/input_suspend_host.mjs "$runtime" "$check_dir/app.js"
    node tests/input_suspend_host.mjs "$runtime" "$check_dir/pending.js" pending
  fi
done
if [ "$(uname -s)" = Linux ]; then
  bend src/LiveParagraph.bend -o "$check_dir/app"
  node tests/input_suspend_host.mjs native "$check_dir/app"
  bend src/LiveParagraph.bend -o "$check_dir/app.c"
  clang -O2 -pthread '-DMARKBEND_SUSPEND_POLL()=((errno=EIO),-1)' "$check_dir/app.c" -o "$check_dir/poll-error"
  node tests/input_suspend_host.mjs native "$check_dir/poll-error"
fi
printf 'Input-ended suspension batch passed\n'
