#!/bin/sh
set -eu
program=$1
runtime=${2:-native}
run_config() {
  if test "$runtime" = native; then "$program"; else "$runtime" "$program"; fi
}
unset MARKBEND_OPEN_PATH
test "$(run_config)" = missing
export MARKBEND_OPEN_PATH=''
test "$(run_config)" = 'path:'
MARKBEND_OPEN_PATH='./中文 😀 document.md'
test "$(run_config)" = 'path:./中文 😀 document.md'
if test "$runtime" = native; then
  MARKBEND_OPEN_PATH=$(printf '\377')
  test "$(run_config)" = invalid
fi
printf 'Startup path checks passed (%s)\n' "$runtime"
