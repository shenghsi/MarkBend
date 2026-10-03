#!/bin/sh
set -eu
program=$1
MARKBEND_ATOMIC_HOST=$2
MARKBEND_IDENTITY_HOST=$3
MARKBEND_DIRECTORY_HOST=$4
MARKBEND_RECOVERY_DIRECTORY=$5
export MARKBEND_ATOMIC_HOST MARKBEND_IDENTITY_HOST MARKBEND_DIRECTORY_HOST MARKBEND_RECOVERY_DIRECTORY
root=$MARKBEND_RECOVERY_DIRECTORY
mkdir "$root" "$root/source" "$root/catalog" "$root/catalog/entry"
MARKBEND_NATIVE_RECOVERY_MODE=write
export MARKBEND_NATIVE_RECOVERY_MODE
if "$program" > "$root/writer.out" 2> "$root/writer.err"; then
  echo 'Native recovery writer did not stop' >&2; exit 1
else test "$?" -eq 79; fi
cp "$root/source/document" "$root/source-before"
cp "$root/catalog/entry/document" "$root/entry-before"
MARKBEND_NATIVE_RECOVERY_MODE=read
"$program"
cmp "$root/source-before" "$root/source/document"
cmp "$root/entry-before" "$root/catalog/entry/document"
test ! -e "$root/source/pending"
test ! -e "$root/catalog/entry/pending"
