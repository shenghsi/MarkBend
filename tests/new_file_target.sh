#!/bin/sh
set -eu
check_dir=$(mktemp -d)
trap 'rm -r "$check_dir"' EXIT HUP INT TERM
clang -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/new_file_target_engine.c -o "$check_dir/engine"
"$check_dir/engine"
bend tests/NewFileTargetCheck.bend -o "$check_dir/target"
bend tests/NewFileTargetCheck.bend -o "$check_dir/target.c"
clang -O2 -pthread -include tests/new_file_target_swap.h "$check_dir/target.c" -o "$check_dir/swap"
node tests/new_file_target_host.mjs native "$check_dir/target" "$check_dir/swap"
bend tests/NewFileTargetCheck.bend -o "$check_dir/target.js"
for runtime in node bun; do
  if command -v "$runtime" >/dev/null 2>&1; then
    node tests/new_file_target_host.mjs "$runtime" "$check_dir/target.js"
  fi
done
printf 'New-file target resolution batch passed\n'
