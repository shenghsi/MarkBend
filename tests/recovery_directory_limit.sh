#!/bin/sh
set -eu
host=$1
fixture=$2
runtime=$3
program=$4
root=$5
mkdir "$root"
"$fixture" create "$root/store"
if "$host" --list "$root/store" > "$root/list"; then
  echo 'Oversized listing was accepted' >&2; exit 1
else test "$?" -eq 1; fi
test -s "$root/list"
test "$(tail -n 1 "$root/list")" != END
test "$(wc -c < "$root/list")" -le 1048576
MARKBEND_DIRECTORY_HOST=$host
MARKBEND_ATOMIC_HOST=$host
MARKBEND_SCAN_ROOT="$root/store"
MARKBEND_SCAN_MODE=retry
MARKBEND_SCAN_DUPLICATE=no
export MARKBEND_DIRECTORY_HOST MARKBEND_ATOMIC_HOST MARKBEND_SCAN_ROOT
export MARKBEND_SCAN_MODE MARKBEND_SCAN_DUPLICATE
mkdir "$root/store-retry"
if [ "$runtime" = native ]; then "$program"; else "$runtime" "$program"; fi
"$fixture" check "$root/store"
echo 'Recovery listing limit check passed'
