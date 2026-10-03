#!/bin/sh
set -eu
check_dir=$(mktemp -d)
trap 'rm -r "$check_dir"' EXIT HUP INT TERM
clang -std=gnu11 -pthread -Wall -Wextra -Werror -fsanitize=address,undefined tests/input_wait_engine.c -o "$check_dir/engine"
"$check_dir/engine"
clang -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/input_wait_work.c -o "$check_dir/work"
"$check_dir/work"
bend tests/InputWaitCheck.bend -o "$check_dir/wait"
node tests/input_wait_host.mjs "$check_dir/wait"
bend tests/InputWaitCheck.bend -o "$check_dir/wait.c"
clang -O2 -pthread -DMARKBEND_INPUT_WAIT_INTERRUPT_ONCE "$check_dir/wait.c" -o "$check_dir/interrupt"
node tests/input_wait_host.mjs "$check_dir/interrupt"
bend tests/InputWaitCheck.bend -o "$check_dir/wait.js"
node "$check_dir/wait.js" unavailable
if command -v bun >/dev/null 2>&1; then
  bun "$check_dir/wait.js" unavailable
fi
printf 'Private input wait batch passed\n'
