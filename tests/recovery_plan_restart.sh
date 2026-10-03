#!/bin/sh
set -eu
runtime=$1
program=$2
MARKBEND_ATOMIC_HOST=$3
MARKBEND_IDENTITY_HOST=$4
MARKBEND_DIRECTORY_HOST=$5
MARKBEND_RECOVERY_DIRECTORY=$6
export MARKBEND_ATOMIC_HOST MARKBEND_IDENTITY_HOST MARKBEND_DIRECTORY_HOST MARKBEND_RECOVERY_DIRECTORY
root=$MARKBEND_RECOVERY_DIRECTORY
mkdir "$root" "$root/a" "$root/b" "$root/catalog" "$root/catalog/entry"
invoke() {
  if [ "$runtime" = native ]; then "$program"; else "$runtime" "$program"; fi
}
export MARKBEND_PLAN_MODE
MARKBEND_PLAN_MODE=write
if invoke > "$root/writer.out" 2> "$root/writer.err"; then
  echo 'Catalog writer did not stop' >&2; exit 1
else test "$?" -eq 79; fi
cmp "$root/a/document" "$root/b/document"
cp "$root/a/document" "$root/source-before"
cp "$root/catalog/entry/document" "$root/entry-before"
for MARKBEND_PLAN_MODE in owner other; do
  invoke
  cmp "$root/source-before" "$root/a/document"
  cmp "$root/source-before" "$root/b/document"
  cmp "$root/entry-before" "$root/catalog/entry/document"
done
# Simulate an external source-file change. The canonical path remains the same.
printf 'X' | dd of="$root/a/document" bs=1 count=1 conv=notrunc 2>/dev/null
cp "$root/a/document" "$root/external-before"
MARKBEND_PLAN_MODE=conflict
invoke
mkdir "$root/catalog/bad"
printf 'broken\000\377' > "$root/catalog/bad/document"
cp "$root/catalog/bad/document" "$root/bad-before"
MARKBEND_PLAN_MODE=review
invoke
cmp "$root/external-before" "$root/a/document"
cmp "$root/source-before" "$root/b/document"
cmp "$root/entry-before" "$root/catalog/entry/document"
cmp "$root/bad-before" "$root/catalog/bad/document"
test ! -e "$root/catalog/entry/pending"
