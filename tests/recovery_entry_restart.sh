#!/bin/sh
# Both files have identical bytes, but only a owns the persisted entry.
set -eu
runtime=$1
program=$2
MARKBEND_ATOMIC_HOST=$3
MARKBEND_RECOVERY_DIRECTORY=$4
MARKBEND_IDENTITY_HOST=$5
MARKBEND_RECOVERY_MODE=write
MARKBEND_RECOVERY_OWNER=a
export MARKBEND_ATOMIC_HOST MARKBEND_RECOVERY_DIRECTORY
export MARKBEND_IDENTITY_HOST
export MARKBEND_RECOVERY_MODE MARKBEND_RECOVERY_OWNER
mkdir "$MARKBEND_RECOVERY_DIRECTORY"
mkdir "$MARKBEND_RECOVERY_DIRECTORY/a" "$MARKBEND_RECOVERY_DIRECTORY/b"
mkdir "$MARKBEND_RECOVERY_DIRECTORY/a/journal"
invoke() {
  if [ "$runtime" = native ]; then "$program"; else "$runtime" "$program"; fi
}
if invoke > "$MARKBEND_RECOVERY_DIRECTORY/writer.out" 2> "$MARKBEND_RECOVERY_DIRECTORY/writer.err"; then
  echo 'Entry writer did not stop' >&2
  exit 1
else
  test "$?" -eq 79
fi
cmp "$MARKBEND_RECOVERY_DIRECTORY/a/document" "$MARKBEND_RECOVERY_DIRECTORY/b/document"
cp "$MARKBEND_RECOVERY_DIRECTORY/a/document" "$MARKBEND_RECOVERY_DIRECTORY/source-before"
cp "$MARKBEND_RECOVERY_DIRECTORY/a/journal/document" "$MARKBEND_RECOVERY_DIRECTORY/entry-before"
MARKBEND_RECOVERY_MODE=read
for MARKBEND_RECOVERY_OWNER in a b; do
  invoke
  cmp "$MARKBEND_RECOVERY_DIRECTORY/source-before" "$MARKBEND_RECOVERY_DIRECTORY/a/document"
  cmp "$MARKBEND_RECOVERY_DIRECTORY/source-before" "$MARKBEND_RECOVERY_DIRECTORY/b/document"
  cmp "$MARKBEND_RECOVERY_DIRECTORY/entry-before" "$MARKBEND_RECOVERY_DIRECTORY/a/journal/document"
  test ! -e "$MARKBEND_RECOVERY_DIRECTORY/a/journal/pending"
done
