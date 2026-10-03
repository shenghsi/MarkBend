#!/bin/sh
set -eu
runtime=$1
program=$2
MARKBEND_DIRECTORY_HOST=$3
MARKBEND_ATOMIC_HOST=$4
root=$5
MARKBEND_SCAN_ROOT="$root/store"
MARKBEND_SCAN_MODE=write
MARKBEND_SCAN_DUPLICATE=no
export MARKBEND_DIRECTORY_HOST MARKBEND_ATOMIC_HOST
export MARKBEND_SCAN_ROOT MARKBEND_SCAN_MODE MARKBEND_SCAN_DUPLICATE
mkdir "$root" "$root/store" "$root/store/a" "$root/store/b" "$root/store/corrupt" "$root/store/empty"
printf 'broken\000\377' > "$root/store/corrupt/document"
printf 'note' > "$root/store/note"
ln -s a "$root/store/alias"
mkfifo "$root/store/fifo"
invoke() {
  if [ "$runtime" = native ]; then "$program"; else "$runtime" "$program"; fi
}
if invoke > "$root/writer.out" 2> "$root/writer.err"; then
  echo 'Scan writer did not stop' >&2; exit 1
else test "$?" -eq 79; fi
cp "$root/store/a/document" "$root/a-before"
cp "$root/store/b/document" "$root/b-before"
cp "$root/store/corrupt/document" "$root/corrupt-before"
MARKBEND_SCAN_MODE=read
invoke
mkdir "$root/store/c"
cp "$root/store/a/document" "$root/store/c/document"
MARKBEND_SCAN_DUPLICATE=yes
invoke
cmp "$root/a-before" "$root/store/a/document"
cmp "$root/b-before" "$root/store/b/document"
cmp "$root/a-before" "$root/store/c/document"
cmp "$root/corrupt-before" "$root/store/corrupt/document"
test -L "$root/store/alias"
test -p "$root/store/fifo"
test ! -e "$root/store/empty/document"
index=0
while [ "$index" -lt 255 ]; do
  mkdir "$root/store/copy-$index"
  cp "$root/a-before" "$root/store/copy-$index/document"
  index=$((index + 1))
done
MARKBEND_SCAN_MODE=large
invoke
index=0
while [ "$index" -lt 255 ]; do
  cmp "$root/a-before" "$root/store/copy-$index/document"
  index=$((index + 1))
done
mkdir "$root/clean" "$root/clean/a" "$root/clean/b"
cp "$root/a-before" "$root/clean/a/document"
cp "$root/b-before" "$root/clean/b/document"
MARKBEND_SCAN_ROOT="$root/clean"
MARKBEND_SCAN_MODE=clean
invoke
cmp "$root/a-before" "$root/clean/a/document"
cmp "$root/b-before" "$root/clean/b/document"
MARKBEND_SCAN_ROOT="$root/missing"
MARKBEND_SCAN_MODE=retry
mkdir "$root/missing-retry"
invoke
cmp "$root/a-before" "$root/store/a/document"
cmp "$root/b-before" "$root/store/b/document"
cmp "$root/a-before" "$root/store/c/document"
cmp "$root/corrupt-before" "$root/store/corrupt/document"
