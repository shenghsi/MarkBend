#!/bin/sh
set -eu
check_dir=$(mktemp -d)
trap 'rm -r "$check_dir"' EXIT HUP INT TERM
bend src/LiveParagraph.bend -o "$check_dir/app"
bend src/LiveParagraph.bend -o "$check_dir/app.c"
clang -O2 -pthread -include tests/new_file_publish_failure.h "$check_dir/app.c" -o "$check_dir/failure"
node tests/app_save_as_terminal.mjs "$check_dir/app" "$check_dir/failure"
