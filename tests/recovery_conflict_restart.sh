#!/bin/sh
# Each operation runs in a fresh process. The reader must not write either file.
set -eu
program=$1
MARKBEND_ATOMIC_HOST=$2
root=$3
runtime=${4:-native}
export MARKBEND_ATOMIC_HOST
mkdir "$root"
invoke() {
  if [ "$runtime" = native ]; then
    "$program"
  else
    "$runtime" "$program"
  fi
}
for MARKBEND_EXTERNAL_HEAD in 67 69; do
  MARKBEND_RECOVERY_DIRECTORY="$root/$MARKBEND_EXTERNAL_HEAD"
  mkdir "$MARKBEND_RECOVERY_DIRECTORY" "$MARKBEND_RECOVERY_DIRECTORY/journal"
  MARKBEND_RECOVERY_MODE=write
  export MARKBEND_EXTERNAL_HEAD MARKBEND_RECOVERY_DIRECTORY MARKBEND_RECOVERY_MODE
  if invoke > "$MARKBEND_RECOVERY_DIRECTORY/writer.out" 2> "$MARKBEND_RECOVERY_DIRECTORY/writer.err"; then
    echo 'Conflict writer did not stop' >&2
    exit 1
  else
    test "$?" -eq 79
  fi
  MARKBEND_RECOVERY_MODE=external
  invoke
  cp "$MARKBEND_RECOVERY_DIRECTORY/document" "$MARKBEND_RECOVERY_DIRECTORY/source-before"
  cp "$MARKBEND_RECOVERY_DIRECTORY/journal/document" "$MARKBEND_RECOVERY_DIRECTORY/journal-before"
  MARKBEND_RECOVERY_MODE=read
  invoke
  cmp "$MARKBEND_RECOVERY_DIRECTORY/source-before" "$MARKBEND_RECOVERY_DIRECTORY/document"
  cmp "$MARKBEND_RECOVERY_DIRECTORY/journal-before" "$MARKBEND_RECOVERY_DIRECTORY/journal/document"
  test ! -e "$MARKBEND_RECOVERY_DIRECTORY/pending"
  test ! -e "$MARKBEND_RECOVERY_DIRECTORY/journal/pending"
done
