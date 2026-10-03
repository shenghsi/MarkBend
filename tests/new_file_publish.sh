#!/bin/sh
set -eu
check_dir=$(mktemp -d)
trap 'rm -r "$check_dir"' EXIT HUP INT TERM
clang -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/new_file_publish_engine.c -o "$check_dir/engine"
"$check_dir/engine"
clang -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/new_file_publish_work.c -o "$check_dir/work"
"$check_dir/work"
bend tests/NewFilePublishCheck.bend -o "$check_dir/publish"
node tests/new_file_publish_host.mjs native "$check_dir/publish"
bend tests/NewFilePublishDriverCheck.bend -o "$check_dir/driver"
bend tests/NewFilePublishDriverCheck.bend -o "$check_dir/driver.c"
clang -O2 -pthread -include tests/new_file_publish_failure.h "$check_dir/driver.c" -o "$check_dir/failure"
node tests/new_file_publish_driver.mjs native "$check_dir/driver" "$check_dir/failure"
bend tests/NewFilePublishCheck.bend -o "$check_dir/publish.js"
bend tests/NewFilePublishDriverCheck.bend -o "$check_dir/driver.js"
for runtime in node bun; do
  if command -v "$runtime" >/dev/null 2>&1; then
    node tests/new_file_publish_host.mjs "$runtime" "$check_dir/publish.js"
    node tests/new_file_publish_driver.mjs "$runtime" "$check_dir/driver.js"
  fi
done
