#!/bin/sh
set -eu
program=$1
atomic=$2
directory=$3
runtime=${4:-native}
restart_root=$(mktemp -d /tmp/markbend-app-recovery.XXXXXX)
trap 'rm -rf "$restart_root"' EXIT HUP INT TERM
restart_root=$(cd "$restart_root" && pwd -P)
mkdir "$restart_root/source" "$restart_root/catalog" "$restart_root/catalog/entry"
printf 'A\r\n' > "$restart_root/source/中文 😀.md"
cp "$restart_root/source/中文 😀.md" "$restart_root/source/other.md"
ln -s 'source/中文 😀.md' "$restart_root/alias.md"
ln -s source/other.md "$restart_root/other-alias.md"
invoke() {
  if test "$runtime" = native; then
    "$program" "$1" "$atomic" "$directory" "$restart_root"
  else
    "$runtime" "$program" "$1" "$atomic" "$directory" "$restart_root"
  fi
}
write_record() {
  if invoke "$1" > "$restart_root/writer.out" 2> "$restart_root/writer.err"; then
    exit 1
  else test "$?" -eq 79; fi
}
write_record write
test -s "$restart_root/catalog/entry/document"
cp "$restart_root/catalog/entry/document" "$restart_root/entry-before"
cp "$restart_root/source/other.md" "$restart_root/other-before"
read_case() {
  cp "$restart_root/source/中文 😀.md" "$restart_root/source-before"
  find "$restart_root/source" "$restart_root/catalog" -print | LC_ALL=C sort > "$restart_root/names-before"
  invoke "$1"
  find "$restart_root/source" "$restart_root/catalog" -print | LC_ALL=C sort > "$restart_root/names-after"
  cmp "$restart_root/names-before" "$restart_root/names-after"
  cmp "$restart_root/source-before" "$restart_root/source/中文 😀.md"
  cmp "$restart_root/other-before" "$restart_root/source/other.md"
  cmp "$restart_root/entry-before" "$restart_root/catalog/entry/document"
  if test -e "$restart_root/catalog/bad/document"; then
    cmp "$restart_root/bad-before" "$restart_root/catalog/bad/document"
  fi
  if test -e "$restart_root/catalog/duplicate/document"; then
    cmp "$restart_root/duplicate-before" "$restart_root/catalog/duplicate/document"
  fi
  test ! -e "$restart_root/catalog/entry/pending"
}
read_case owner
read_case other
printf 'B\r\n' > "$restart_root/source/中文 😀.md"
read_case pending
printf 'X\r\n' > "$restart_root/source/中文 😀.md"
read_case conflict
mkdir "$restart_root/catalog/bad"
printf 'broken\000\377' > "$restart_root/catalog/bad/document"
cp "$restart_root/catalog/bad/document" "$restart_root/bad-before"
read_case review
cmp "$restart_root/bad-before" "$restart_root/catalog/bad/document"
# Keep the review record in a separate catalog outside the scan root.
mv "$restart_root/catalog/bad" "$restart_root/rejected-record"
printf 'A\r\n' > "$restart_root/source/中文 😀.md"
mkdir "$restart_root/catalog/duplicate"
write_record duplicate-write
cp "$restart_root/catalog/duplicate/document" "$restart_root/duplicate-before"
read_case duplicate
cmp "$restart_root/duplicate-before" "$restart_root/catalog/duplicate/document"
cmp "$restart_root/bad-before" "$restart_root/rejected-record/document"
test ! -e "$restart_root/catalog/duplicate/pending"
