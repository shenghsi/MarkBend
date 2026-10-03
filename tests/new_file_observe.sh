#!/bin/sh
set -eu
check_dir=$(mktemp -d)
trap 'rm -r "$check_dir"' EXIT HUP INT TERM
clang -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/new_file_observe_engine.c -o "$check_dir/engine"
"$check_dir/engine"
clang -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/new_file_observe_work.c -o "$check_dir/work"
"$check_dir/work"
bend tests/NewFileObserveCheck.bend -o "$check_dir/observe"
node tests/new_file_observe_host.mjs native "$check_dir/observe"
bend tests/NewFileObserveDriverCheck.bend -o "$check_dir/driver"
node tests/new_file_observe_driver.mjs native "$check_dir/driver"
bend tests/NewFileObserveCheck.bend -o "$check_dir/observe.js"
bend tests/NewFileObserveDriverCheck.bend -o "$check_dir/driver.js"
for runtime in node bun; do
  if command -v "$runtime" >/dev/null 2>&1; then
    node tests/new_file_observe_host.mjs "$runtime" "$check_dir/observe.js"
    node tests/new_file_observe_driver.mjs "$runtime" "$check_dir/driver.js"
  fi
done
