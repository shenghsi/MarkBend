#!/bin/sh
set -eu
program=$1
runtime=${2:-native}
invoke() {
  if test "$runtime" = native; then "$program"; else "$runtime" "$program"; fi
}
unset MARKBEND_STARTUP_RECOVERY_HOST MARKBEND_STARTUP_RECOVERY_ROOT
test "$(invoke)" = disabled
export MARKBEND_STARTUP_RECOVERY_HOST='./中文 😀 host'
test "$(invoke)" = invalid
unset MARKBEND_STARTUP_RECOVERY_HOST
export MARKBEND_STARTUP_RECOVERY_ROOT='./目录 😀'
test "$(invoke)" = invalid
export MARKBEND_STARTUP_RECOVERY_HOST=''
test "$(invoke)" = invalid
MARKBEND_STARTUP_RECOVERY_HOST='./中文 😀 host'
MARKBEND_STARTUP_RECOVERY_ROOT=''
test "$(invoke)" = invalid
MARKBEND_STARTUP_RECOVERY_ROOT='./目录 😀'
if test "$runtime" = node; then
  test "$(invoke)" = 'unavailable:./中文 😀 host:./目录 😀'
else
  test "$(invoke)" = 'enabled:./中文 😀 host:./目录 😀'
fi
if test "$runtime" = native; then
  MARKBEND_STARTUP_RECOVERY_HOST=$(printf '\377')
  test "$(invoke)" = invalid
fi
printf 'Recovery startup configuration passed (%s)\n' "$runtime"
